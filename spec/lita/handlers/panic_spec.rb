require "spec_helper"

describe Lita::Handlers::Panic, lita_handler: true do
  let!(:bob)   { build_user "bob" }
  let!(:lilly) { build_user "lilly", groups: [:instructors, :staff] }
  let!(:joe)   { build_user "joe" }

  it { should route_command("how is everyone doing?").with_authorization_for(:instructors).to(:poll) }
  it { should route_command("how's everybody in #channel?").with_authorization_for(:instructors).to(:poll) }
  it { should route_command("how’s everybody in #channel?").with_authorization_for(:instructors).to(:poll) }
  it { should route_command("1").to(:answer) }
  it { should route_command("Today was awful. Definitely a 6.").to(:answer) }
  it { should_not route_command("This is a response with no numbers") }

  describe "#poll" do
    let(:roster) { [lilly, bob].map &:id }

    before do
      allow(robot).to receive(:roster).and_return(roster)
    end

    describe "with an active poll" do
      before do
        send_command("how is everyone doing?", as: lilly, from: Lita::Room.create_or_update("#lita.io"))
      end

      it "asks everyony how they are doing" do
        expect(replies.size).to eq 3
        expect(replies.first).to eq "I don't know. I'll ask them."
        expect(replies.last).to eq "Hey, how are you doing (on a scale of 1 (boredom) to 6 (panic))?"
      end

      it "records feedback" do
        send_command("I'm okay. About a 4.", as: bob)
        expect(replies_to(bob).last).to eq "Roger, thanks for the feedback"
      end

      it "does not respond to messages from public rooms" do
        expect do
          send_message("Here's a PR for marvin issue 4", as: bob, from: Lita::Room.create_or_update("#lita.io"))
        end.not_to change { replies.count }
      end

      it "does not respond to users which aren't in the room" do
        expect { send_command("2", as: joe) }.not_to change { replies.count }
      end

      describe "with a larger class" do
        let(:roster) { [lilly, bob, joe].map &:id }

        it "notifies the poller once everyone has responded" do
          expect { send_command("3", as: joe) }.not_to change { replies_to(lilly).count }
          expect { send_command("2", as: bob) }.to change { replies_to(lilly).count }.by 1
          expect(replies_to(lilly).last).to match /results are in/i
        end

        it "does notify the poller if anyone is panicked" do
          send_command("6", as: joe)
          expect(replies_to(lilly).last).to match /Joe is at a 6/
        end

        it "produces a CSV" do
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
          send_command "panic export", as: lilly
          token = replies_to(lilly).last.match(/panic\/(\S+)/)[1]

          response = http.get "/panic/#{token}-miss"
          expect(response.status).to eq 403
          expect(response.body).to be_empty
        end
      end
    end

    describe "error handling" do
      it "will silence cannot_dm_bot errors" do
        allow(robot).to receive(:send_message).twice.and_raise("Slack API call to im.open returned an error: cannot_dm_bot.")
        send_command("how is everyone doing?", as: lilly, from: Lita::Room.create_or_update("#lita.io"))
        expect(replies.size).to eq 1
        expect(replies.first).to eq "I don't know. I'll ask them."
      end

      it "will respond with other errors" do
        allow(robot).to receive(:send_message).twice.and_raise("BOOM")
        send_command("how is everyone doing?", as: lilly, from: Lita::Room.create_or_update("#lita.io"))
        expect(replies.size).to eq 3
        expect(replies.first).to eq "I don't know. I'll ask them."
        expect(replies.last).to match /Shoot, I couldn't reach \w+ because we hit this bug `BOOM`/
      end
    end
  end
end
