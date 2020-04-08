class UserRatingController < ApplicationController
  before_action :auth_by_admin_api_key

  def auth_by_admin_api_key
    authenticate_or_request_with_http_token do |token, options|
      (token == ENV['CROWDAI_API_KEY'])
    end
  end

  def get_leaderboard_ranks
    user_rating_service = UserRatingService.new(params[:round_id])
    leaderboard_rating_stats = user_rating_service.leaderboard_query
    puts leaderboard_rating_stats
    ranks, teams_mu, teams_sigma, teams_participant_ids = user_rating_service.filter_leaderboard_stats leaderboard_rating_stats
    response = {
        ranks: ranks,
        teams_mu: teams_mu,
        teams_sigma: teams_sigma,
        teams_participant_ids: teams_participant_ids
    }
    puts response
    render json: response.to_json
  end
  def post_new_participant_ratings
    if params[:calculate_leaderboard]
      ParticipantRatingRanksQuery.new.call
      response = {
          success: true
      }
      render json: response.to_json
    end
    user_rating_service = UserRatingService.new(params[:round_id])
    teams_participant_ids, new_team_ratings, new_team_variations = params[:participant_ids], params[:final_rating], params[:final_variation]
    if new_team_ratings.blank? && new_team_variations.blank?
      participant_ids, new_participant_ratings, new_participant_variations = user_rating_service.filter_rating_api_output teams_participant_ids, new_team_ratings, new_team_variations
      user_rating_service.update_database_columns participant_ids, new_participant_ratings, new_participant_variations
    end
  end
end

