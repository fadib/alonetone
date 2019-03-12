require "rails_helper"

RSpec.describe User, type: :model do
  context "validation" do
    it "should be valid with email, login and password" do
      expect(new_user).to be_valid
      expect(users(:sudara)).to be_valid
    end

    it "should validate logins" do
      expect(new_user(login: "bobbyf")).to be_valid
      expect(new_user(login: "BobbyF")).to be_valid
      expect(new_user(login: "r00ter")).to be_valid
      expect(new_user(login: "with spaces")).not_to be_valid
      expect(new_user(login: "with_underscore")).to be_valid
      expect(new_user(login: "!7384.")).not_to be_valid
      expect(new_user(login: "aa")).not_to be_valid
    end

    # https://www.wikiwand.com/en/Email_address#/Examples
    it "should validate email" do
      expect(new_user(email: "userEmail1&@gmail.com")).to be_valid
      expect(new_user(email: "userEmail1&@gmail.")).not_to be_valid
      expect(new_user(email: "Abc.example.com")).not_to be_valid
      expect(new_user(email: "A@b@c@example.com")).not_to be_valid
      expect(new_user(email: "a\"b(c)d,e:f;g<h>i[j\k]l@example.com")).not_to be_valid
      expect(new_user(email: 'just"not"right@example.com')).not_to be_valid
      expect(new_user(email: 'this is"not\allowed@example.com')).not_to be_valid
      expect(new_user(email: 'this\ still\"not\\allowed@example.com ')).not_to be_valid
      expect(new_user(email: 'expect(new_user(email: "Abc.example.com")).not_to be_valid')).not_to be_valid
    end

    it "can be an admin" do
      expect(users(:sudara)).to be_admin
    end

    it "can be a mod" do
      expect(users(:sandbags)).to be_moderator
    end

    it "should not require a profile on update" do
      @user = new_user
      @user.save
      @user.save
      expect(@user).to be_valid
    end
  end

  context "activation" do
    it "is considered active when persishble token doesn't exist" do
      expect(users(:arthur)).to be_active
    end

    it "is not active when perishable token exists" do
      expect(users(:not_activated).perishable_token).to be_present
      expect(users(:not_activated)).not_to be_active
    end

    it "can be activated and deactivated" do
      users(:not_activated).activate!
      expect(users(:not_activated)).to be_active
      users(:not_activated).reset_perishable_token!
      expect(users(:not_activated)).not_to be_active
    end
  end

  context "relations" do
    it 'has tracks called assets' do
      expect(users(:arthur).assets).to be_present
    end

    it 'has a favorites playlist and tracks' do
      # users(:arthur).favorites.should be_present
    end
  end

  context "deletion" do
    it 'should remove listens tracks playlists posts topics comments assets as well' do
    end
  end

  describe "generating URLs to an avatar" do
    context "with an avatar" do
      let(:user) { users(:sudara) }

      it "knows the user has an avatar" do
        expect(user.avatar_image_present?).to eq(true)
      end

      it "returns a URL to a variant" do
        url = user.avatar_url(variant: :large)
        expect(url).to start_with('/system/pics')
        expect(url).to end_with('.jpg')
      end
    end

    context "with an avatar that has missing information" do
      let(:user) { users(:aaron) }

      it "knows the user does not have an avatar" do
        expect(user.avatar_image_present?).to eq(false)
      end

      it "does not return a URL to a variant" do
        expect(user.avatar_url(variant: :large)).to be_nil
      end
    end

    context "without an avatar" do
      let(:user) { users(:arthur) }

      it "knows the user does not have an avatar" do
        expect(user.avatar_image_present?).to eq(false)
      end

      it "does not return a URL to a variant" do
        expect(user.avatar_url(variant: :large)).to be_nil
      end
    end
  end

  protected

  def new_user(options = {})
    User.new({ email: 'new@user.com', login: 'newuser', password: 'quire451', password_confirmation: 'quire451' }.merge(options))
  end
end
