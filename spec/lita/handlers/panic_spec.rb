require "spec_helper"
describe Lita::Handlers::Panic, lita_handler: true do
  let!(:bob)   { build_user "bob" }
  let!(:lilly) { build_user "lilly", groups: [:instructors, :staff] }
  let!(:joe)   { build_user "joe" }

  let!(:slack_room) { Lita::Room.create_or_update("C2K5FD831", {name: "lita.io"}) }

  it { should route_command("how is everyone doing?").with_authorization_for(:instructors).to(:poll) }
  it { should route_command("panic status of #channel?").with_authorization_for(:instructors).to(:status) }
  it { should route_command("panic status of channel?").with_authorization_for(:instructors).to(:status) }
  it { should route_command("panic of #channel?").with_authorization_for(:instructors).to(:status) }
  it { should_not route_command("panic status #channel?").with_authorization_for(:instructors).to(:status) }
  it { should route_command("how's everybody in #channel?").with_authorization_for(:instructors).to(:poll) }
  it { should route_command("how’s everybody in #channel?").with_authorization_for(:instructors).to(:poll) }
  it { should route_command("1").to(:answer) }
  it { should route_command("Today was awful. Definitely a 6.").to(:answer) }
  it { should route_command("panic export").with_authorization_for(:instructors).to(:export) }
  it { should route_command("panic export #lita.io").with_authorization_for(:instructors).to(:export) }
  it { should_not route_command("This is a response with no numbers") }

  describe "#poll" do
    let(:roster) { [lilly, bob].map(&:id) }

    before do
      allow(robot).to receive(:roster).and_return(roster)
    end

    it "reminds students who have not responded" do
      allow_any_instance_of(Lita::Timer).to receive(:sleep)
      send_command("how is everyone doing?", as: lilly, from: slack_room)
      sleep 0.1
      expect(replies_to(bob).last).to eq "Hey, I haven't heard from you. How are you doing (on a scale of 1 (boredom) to 6 (panic))?"
    end

    describe "with an active poll" do
      before do
        send_command("how is everyone doing?", as: lilly, from: slack_room)
      end

      it "asks everyony how they are doing" do
        expect(replies.size).to eq 2
        expect(replies.first).to eq "I don't know. I'll ask them."
        expect(replies.last).to eq "Hey, how are you doing (on a scale of 1 (boredom) to 6 (panic))?"
      end

      it "can be asked for status" do
        send_command("panic of lita.io?", as: lilly)
        expect(replies_to(lilly).last).to match(/bob/)
        expect(replies_to(lilly).last).to match(/The current results/)
      end

      it "records feedback" do
        send_command("I'm okay. About a 4.", as: bob)
        expect(replies_to(bob).last).to eq "Roger, thanks for the feedback"
      end

      it "clears redis of pending polls" do
        send_command("I'm okay. About a 4.", as: bob)
        expect{send_command("I'm okay. About a 4.", as: bob)}.to_not change{replies_to(bob).size}
      end

      it "does not respond to messages from public rooms" do
        expect do
          send_message("Here's a PR for marvin issue 4", as: bob, from: slack_room)
        end.not_to change { replies.count }
      end

      it "does not respond to users which aren't in the room" do
        expect { send_command("2", as: joe) }.not_to change { replies.count }
      end

      describe "with a larger class" do
        let(:roster) { [lilly, bob, joe].map(&:id) }

        it "notifies the poller once everyone has responded" do
          expect { send_command("3", as: joe) }.not_to change { replies_to(lilly).count }
          expect { send_command("2", as: bob) }.to change { replies_to(lilly).count }.by 1
          expect(replies_to(lilly).last).to match(/results are in/i)
        end

        it "does notify the poller if anyone is panicked" do
          send_command("6", as: joe)
          expect(replies_to(lilly).last).to match(/Joe is at a 6/)
        end

        it "can be asked for the status of a room by the poster" do
          send_command "3", as: joe
          send_command("panic of #lita.io", as: lilly)
          expect(replies_to(lilly).last).to match(/joe>: 3/)
          expect(replies_to(lilly).last).to match(/bob>: \n/)
        end

        it "produces a CSV" do
          send_command "3", as: joe
          send_command "2", as: bob

          send_command "panic export #lita.io", as: lilly
          token = replies_to(lilly).last.match(/panic\/(\S+)\/lita.io/)[1]

          csv = http.get("/panic/#{token}/lita.io").body

          joe_row = CSV.parse(csv, headers: true).find { |r| r["User"] == joe.name }
          last_response = joe_row.to_a.pop.pop
          expect(last_response).to eq "3"
        end

        it 'will produce a CSV of all rooms if no room provided' do
          send_command "3", as: joe
          send_command "2", as: bob

          send_command "panic export", as: lilly
          token = replies_to(lilly).last.match(/panic\/(\S+)/)[1]

          csv = http.get("/panic/#{token}").body

          joe_row = CSV.parse(csv, headers: true).find { |r| r["User"] == joe.name }
          last_response = joe_row.to_a.pop.pop
          expect(last_response).to eq "3"
        end

        it "protects CSV access with tokens" do
          send_command "panic export #lita.io", as: lilly
          token = replies_to(lilly).last.match(/panic\/(\S+)\/lita.io/)[1]

          response = http.get "/panic/#{token}-miss/lita.io"
          expect(response.status).to eq 403
          expect(response.body).to be_empty
        end
      end
    end

    describe "error handling" do
      it "will silence cannot_dm_bot errors" do
        allow(robot).to receive(:send_message).twice.and_raise("Slack API call to im.open returned an error: cannot_dm_bot.")
        send_command("how is everyone doing?", as: lilly, from: slack_room)
        expect(replies.size).to eq 1
        expect(replies.first).to eq "I don't know. I'll ask them."
      end

      it "will respond with other errors" do
        expect(robot).to receive(:send_message).with(any_args, /how are you doing /).and_raise("BOOM")
        allow(robot).to receive(:send_message).and_call_original

        send_command("how is everyone doing?", as: lilly, from: slack_room)
        expect(replies.size).to eq 2
        expect(replies.first).to eq "I don't know. I'll ask them."
        expect(replies.last).to match(/Shoot, I couldn't reach \w+ because we hit this bug `BOOM`/)
      end
    end
  end
end
