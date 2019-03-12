require "rails_helper"

RSpec.describe UsersController, type: :controller do
  context "index" do
    it "should only show active and non spam users" do
      users(:arthur).update_attributes(is_spam: true)

      get :index
      expect(response).to be_successful
      expect(assigns(:users).count).to eq(User.count - 2)
      expect(assigns(:users)).not_to include(users(:arthur))
    end
  end

  context 'show' do
    it "should show delete user button for admins" do
      login(:sudara)

      get :show, params: { id: 'arthur' }
      expect(response).to be_successful
      expect(response.body).to include('Delete User')
    end

    it "should NOT show delete user button for muggles" do
      login(:arthur)

      get :show, params: { id: 'sudara' }
      expect(response).to be_successful
      expect(response.body).not_to include('Delete User')
    end

    it "should NOT show delete user button for own account" do
      login(:arthur)

      get :show, params: { id: 'arthur' }
      expect(response).to be_successful
      expect(response.body).not_to include('Delete User')
    end
  end

  context 'creating' do
    before :each do
      akismet_stub_response_ham
    end

    it "should successfully post to users/create" do
      set_good_request_headers && create_user
      expect(response).to redirect_to("/login?already_joined=true")
    end

    it "should send user activation email after signup" do
      expect {
        set_good_request_headers && create_user
      }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(last_email.to).to eq(["quire@example.com"])
    end

    it "should not send user activation email if bad ip" do
      expect {
        set_good_request_headers
        @request.env['REMOTE_ADDR'] = '60.169.78.123' # example bad ip
        create_user
      }.to change { ActionMailer::Base.deliveries.size }.by(0)
    end

    it "should not send user activation email if bad user agent" do
      expect {
        set_good_request_headers
        @request.env['HTTP_USER_AGENT'] = 'bot'
        create_user
      }.to change { ActionMailer::Base.deliveries.size }.by(0)
    end

    it "should have actually created the user" do
      expect { set_good_request_headers && create_user }.to change(User, :count).by(1)
    end

    it 'should reset the perishable token' do
      set_good_request_headers && create_user
      expect(assigns(:user).perishable_token).to_not be_nil
    end

    it "should require login on signup" do
      set_good_request_headers
      create_user login: nil
      expect(response).to_not be_redirect
      expect(assigns(:user).errors[:login].size).to be >= 1
    end

    it "should require password on signup" do
      akismet_stub_response_ham
      set_good_request_headers
      create_user password: nil
      expect(response).to_not be_redirect
      expect(assigns(:user).errors[:password].size).to be >= 1
    end

    it "should require password confirmation on signup" do
      set_good_request_headers
      create_user password_confirmation: nil
      expect(response).to be_successful
      expect(assigns(:user).errors[:password_confirmation].size).to be >= 1
    end

    it "should require email on signup" do
      set_good_request_headers
      create_user email: nil
      expect(response).to be_successful
      expect(assigns(:user).errors[:email].size).to be >= 1
    end
  end

  context 'activation' do
    before :each do
      akismet_stub_response_ham
    end

    it "should activate with a for reals perishable token" do
      set_good_request_headers && activate_authlogic && create_user
      get :activate, params: { perishable_token: User.last.perishable_token }
      expect(flash[:ok]).to be_present
      expect(response).to redirect_to(new_user_track_path(User.last.login))
    end

    it 'should log in user on activation' do
      set_good_request_headers && activate_authlogic && create_user
      # expect(UserSession).to receive(:create)
      get :activate, params: { perishable_token: User.last.perishable_token }
      expect(controller.session["user_credentials"]).to eq(User.last.persistence_token)
    end

    it 'should send out email on activation' do
      set_good_request_headers && activate_authlogic && create_user
      get :activate, params: { perishable_token: User.last.perishable_token }
      expect(last_email.to).to eq(["quire@example.com"])
    end

    it "should not activate with bullshit perishable token" do
      set_good_request_headers && activate_authlogic
      get :activate, params: { perishable_token: "abunchofbullshit" }
      expect(flash[:error]).to be_present
      expect(response).to redirect_to(new_user_path)
    end

    it 'should NOT activate an account if you are already logged in' do
      login(:arthur)
      set_good_request_headers && create_user
      get :activate, params: { perishable_token: User.last.perishable_token }
      expect(flash[:error]).to be_present
      expect(response).to redirect_to("http://test.host/arthur/tracks/new")
    end
  end

  context "profile" do
    %i[sudara arthur].each do |user|
      it "should let a user or admin edit" do
        login(user)
        allow(controller).to receive(:current_user).and_return(users(user))
        post :edit, params: { id: 'arthur' }
        expect(response).to be_successful
      end

      it "should let a user or admin update" do
        login(user)
        allow(controller).to receive(:current_user).and_return(users(user))
        put :update, params: { id: 'arthur', user: { bio: 'a little more about me' } }
        expect(response).to redirect_to(edit_user_path(users(:arthur)))
      end
    end

    it "should let a user upload a new photo" do
      login(:arthur)
      post :attach_pic, params: { id: users(:arthur).login, pic: { pic: fixture_file_upload('images/jeffdoessudara.jpg', 'image/jpeg') } }
      expect(flash[:ok]).to be_present
      expect(response).to redirect_to(edit_user_path(users(:arthur)))
    end

    it "should not let a user upload a new photo for another user" do
      login(:arthur)
      post :attach_pic, params: { id: users(:sudara).login, pic: { pic: fixture_file_upload('images/jeffdoessudara.jpg', 'image/jpeg') } }
      expect(response).to redirect_to('/login')
    end

    it "should let a user change their login" do
      login(:arthur)
      put :update, params: { id: 'arthur', user: { login: 'arthursaurus' } }
      expect(flash[:error]).not_to be_present
      expect(response).to be_redirect
      expect(User.where(login: 'arthursaurus').count).to eq(1)
    end

    it 'should not let a user change login to login that exists' do
      login(:arthur)
      put :update, params: { id: 'arthur', user: { login: 'sudara' } }
      expect(flash[:error]).to be_present
      expect(User.where(login: 'sudara').count).to eq(1)
    end

    it "should not let any old user edit" do
      login(:arthur)
      allow(controller).to receive(:current_user).and_return(users(:arthur))
      post :edit, params: { id: 'sudara' }
      expect(response).not_to be_successful
    end

    it "should not let any old user update" do
      login(:arthur)
      allow(controller).to receive(:current_user).and_return(users(:arthur))
      put :update, params: { id: 'sudara', user: { bio: 'a little more about me' } }
      expect(response).not_to be_successful
    end

    it "should not let a logged out user edit" do
      logout
      post :edit, params: { user_id: 'arthur' }
      expect(response).not_to be_successful
    end
  end

  context "favoriting" do
    let(:asset) { assets(:valid_mp3_2) }
    subject { get :toggle_favorite, params: { asset_id: asset.id }, xhr: true }

    it 'should not let a guest favorite a track' do
      expect { subject }.to change { Track.count }.by(0)
      expect(response).not_to be_successful
    end

    it 'should let a user favorite a track' do
      login(:arthur)
      expect { subject }.to change { Track.count }.by(1)
      expect(users(:arthur).tracks.favorites.collect(&:asset)).to include(asset)
      expect(response).to be_successful
    end

    it 'should let a user unfavorite a track' do
      login(:arthur)
      expect { subject }.to change { Track.count }.by(1)
      get :toggle_favorite, params: { asset_id: asset.id }, xhr: true # toggle again
      expect(users(:arthur).tracks.favorites.collect(&:asset)).not_to include(asset)
      expect(response).to be_successful
    end
  end

  context "sudo" do
    it "should not let a normal user sudo" do
      controller.session[:return_to] = '/users'
      login(:arthur)
      get :sudo, params: { id: 'sudara' }
      expect(flash[:ok]).not_to be_present
      expect(response).to redirect_to '/'
    end

    it "should let an admin user sudo" do
      login(:sudara)
      controller.session[:return_to] = '/users'
      get :sudo, params: { id: 'arthur' }
      expect(flash[:ok]).to be_present
      expect(controller.session["user_credentials"]).to eq(users(:arthur).persistence_token)
      expect(response).to redirect_to '/users'
    end

    it "should let an sudo'd user return to their admin account" do
      login(:arthur)
      controller.session[:return_to] = '/users'
      controller.session[:sudo] = users(:sudara).id
      get :sudo, params: { id: 'arthur' }
      expect(flash[:ok]).to be_present
      expect(controller.session["user_credentials"]).to eq(users(:sudara).persistence_token)
      expect(response).to redirect_to '/users'
    end

    it "should not update IP or last_request_at" do
      request.env['REMOTE_ADDR'] = '10.1.1.1'
      login(:sudara)
      get :sudo, params: { id: 'arthur' }
      expect(controller.session["user_credentials"]).to eq(users(:arthur).persistence_token)
      expect(users(:arthur).current_login_ip).to eq('9.9.9.9')
      expect(users(:arthur).last_request_at.utc).to be < 1.hour.ago
    end
  end

  context "last request at" do
    it "should touch last_request_at when logging in" do
      # Authlogic does this by default, which fucks things up
      expect { login(:arthur) }.to change { users(:arthur).last_request_at }
    end
  end
end

def set_good_request_headers
  @request.env['HTTP_USER_AGENT'] = 'Safari'
  @request.env['REMOTE_ADDR'] = '10.1.1.1'
end

def create_user(options = {})
  travel_to 1.day.ago do
    post :create, params: { user: { login: 'quire', email: 'quire@example.com', password: 'quire12345', password_confirmation: 'quire12345' }.merge(options) }
  end
end
