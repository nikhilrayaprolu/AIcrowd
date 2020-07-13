module Api
  module V1
    module Organizers
      class ParticipantOrganizersController < ::Api::V1::BaseController
        before_action :auth_by_admin_api_key
        before_action :set_organizer, only: [:create, :destroy]

        def create
          participant_organizer = @organizer.participant_organizers.new(participant_organizer_params)

          if participant_organizer.save
            render json: Api::V1::ParticipantOrganizerSerializer.new(participant_organizer: participant_organizer).serialize, status: :created
          else
            render json: { error: participant_organizer.errors.full_messages.to_sentence }, status: :unprocessable_entity
          end
        end

        private

        def set_organizer
          @organizer = Organizer.friendly.find(params[:organizer_id])
        end

        def participant_organizer_params
          params.permit(
            :participant_id
          )
        end
      end
    end
  end
end
