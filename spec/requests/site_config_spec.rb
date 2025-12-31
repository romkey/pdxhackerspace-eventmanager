require 'rails_helper'

RSpec.describe "SiteConfig", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:site_config) { SiteConfig.instance }

  describe "GET /site_config/edit" do
    context "as a guest" do
      it "redirects to sign in" do
        get edit_site_config_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular user" do
      before { sign_in user }

      it "redirects with unauthorized message" do
        get edit_site_config_path
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to include("not authorized")
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "shows the edit form" do
        get edit_site_config_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Site Configuration")
      end

      it "shows current values" do
        site_config.update!(organization_name: "My Hackerspace")
        get edit_site_config_path
        expect(response.body).to include("My Hackerspace")
      end
    end
  end

  describe "PATCH /site_config" do
    let(:update_params) do
      {
        site_config: {
          organization_name: "Updated Hackerspace",
          contact_email: "contact@updated.org",
          contact_phone: "(555) 999-8888",
          footer_text: "Custom footer text"
        }
      }
    end

    context "as a guest" do
      it "redirects to sign in" do
        patch site_config_path, params: update_params
        expect(response).to have_http_status(:redirect)
      end

      it "does not update the configuration" do
        original_name = site_config.organization_name
        patch site_config_path, params: update_params
        site_config.reload
        expect(site_config.organization_name).to eq(original_name)
      end
    end

    context "as a regular user" do
      before { sign_in user }

      it "redirects with unauthorized message" do
        patch site_config_path, params: update_params
        expect(response).to have_http_status(:redirect)
      end

      it "does not update the configuration" do
        original_name = site_config.organization_name
        patch site_config_path, params: update_params
        site_config.reload
        expect(site_config.organization_name).to eq(original_name)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "updates the configuration" do
        patch site_config_path, params: update_params
        site_config.reload

        expect(site_config.organization_name).to eq("Updated Hackerspace")
        expect(site_config.contact_email).to eq("contact@updated.org")
        expect(site_config.contact_phone).to eq("(555) 999-8888")
        expect(site_config.footer_text).to eq("Custom footer text")
      end

      it "redirects to edit page" do
        patch site_config_path, params: update_params
        expect(response).to redirect_to(edit_site_config_path)
      end

      it "shows success message" do
        patch site_config_path, params: update_params
        follow_redirect!
        expect(response.body).to include("successfully updated")
      end

      context "with invalid params" do
        let(:invalid_params) do
          { site_config: { organization_name: "" } }
        end

        it "does not update" do
          original_name = site_config.organization_name
          patch site_config_path, params: invalid_params
          site_config.reload
          expect(site_config.organization_name).to eq(original_name)
        end

        it "renders edit template" do
          patch site_config_path, params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "removing attachments" do
        it "removes favicon when requested" do
          site_config.favicon.attach(
            io: StringIO.new("test"),
            filename: "test.ico",
            content_type: "image/x-icon"
          )

          patch site_config_path, params: { site_config: { remove_favicon: '1' } }
          site_config.reload
          expect(site_config.favicon.attached?).to be false
        end

        it "removes banner when requested" do
          site_config.banner_image.attach(
            io: StringIO.new("test"),
            filename: "test.jpg",
            content_type: "image/jpeg"
          )

          patch site_config_path, params: { site_config: { remove_banner_image: '1' } }
          site_config.reload
          expect(site_config.banner_image.attached?).to be false
        end
      end
    end
  end
end
