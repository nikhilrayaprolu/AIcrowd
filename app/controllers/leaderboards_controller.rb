class LeaderboardsController < ApplicationController
  before_action :authenticate_participant!, except: [:index, :get_affiliation]
  before_action :set_challenge, only: [:index, :export, :get_affiliation]
  before_action :set_current_round, only: [:index, :export, :get_affiliation]
  before_action :set_leaderboards, only: [:index, :get_affiliation]
  before_action :set_filter_service, only: [:index, :get_affiliation]

  respond_to :js, :html

  def index
    unless is_disentanglement_leaderboard?(@leaderboards.first)
      @submitter_submissions = {}
      @leaderboards.each do |leaderboard|
        next if leaderboard.submitter_type == 'OldParticipant'

        submitter = leaderboard.submitter
        @submitter_submissions.merge!("submitter#{submitter.id}_submissions_by_day": submitter_submissions(submitter).group_by_created_at) if submitter.present?
      end
    end
    @top_three_winners = @leaderboards.where(baseline: false).first(3)
    if params[:country_name].present? || params[:affiliation].present?
      @leaderboards = @leaderboards.where(id: @filter.call('leaderboard_ids'))
      @leaderboards = paginate_leaderboards_by(:seq)
    else
      @leaderboards     = if is_disentanglement_leaderboard?(@leaderboards.first)
                            paginate_leaderboards_by(:row_num)
                          else
                            paginate_leaderboards_by(:seq)
                          end
    end
    @vote             = @challenge.votes.find_by(participant_id: current_participant.id) if current_participant.present?
    @follow           = @challenge.follows.find_by(participant_id: current_participant.id) if current_participant.present?
    @challenge_rounds = @challenge.challenge_rounds.started
    @post_challenge   = post_challenge?
    @following        = following?

    unless is_disentanglement_leaderboard?(@leaderboards.first)
      @countries = @filter.call('participant_countries')
      @affiliations = @filter.call('participant_affiliations')
    end
  end

  def export
    authorize @challenge, :export?

    @leaderboards = Leaderboard
      .where(challenge_round_id: params[:leaderboard_export_challenge_round_id].to_i)
      .order(:seq)

    csv_data = Leaderboards::CSVExportService.new(leaderboards: @leaderboards).call.value

    send_data csv_data,
              type:     'text/csv',
              filename: "#{@challenge.challenge.to_s.parameterize.underscore}_leaderboard_export.csv"
  end

  def get_affiliation
    @affiliations = @filter.call('participant_affiliations')
  end

  private

  def set_challenge
    @challenge = Challenge.friendly.find(params[:challenge_id])
    challenge_type = params['ml_challenge_id'].present? ? 'ml_challenge_id' : 'meta_challenge_id'

    if params.has_key?(challenge_type) and params[challenge_type.to_sym] != params[:challenge_id]
      @meta_challenge = Challenge.includes(:organizers).friendly.find(params[challenge_type.to_sym])
    elsif @challenge.meta_challenge
      params[challenge_type.to_sym] = params[:challenge_id]
    elsif @challenge.ml_challenge
      params[challenge_type.to_sym] = params[:challenge_id]
    end

    if !params.has_key?(challenge_type)
      cp = ChallengeProblems.find_by(problem_id: @challenge.id)
      if cp.present? && params[:action] != 'get_affiliation'
        params[challenge_type.to_sym] = Challenge.find(cp.challenge_id).slug
        redirect_to helpers.challenge_leaderboards_path(@challenge)
      end
    end
  end

  def set_current_round
    @current_round = if params[:challenge_round_id].present?
      @challenge.challenge_rounds.find(params[:challenge_round_id].to_i)
    else
      @challenge.active_round
    end
  end

  def post_challenge?
    @challenge.completed? && params[:post_challenge] == "true" && !@challenge.meta_challenge?
  end

  def following?
    params[:following] == 'true'
  end

  def set_leaderboards
    filter = { challenge_round_id: @current_round&.id.to_i, meta_challenge_id: nil }

    if @meta_challenge.present?
      filter[:meta_challenge_id] = @meta_challenge.id
    end
    @leaderboards = if @challenge.challenge == "NeurIPS 2019 : Disentanglement Challenge"
      DisentanglementLeaderboard
        .where(challenge_round_id: @current_round)
        .freeze_record(current_participant)
    elsif post_challenge? || freeze_record_for_organizer
      policy_scope(OngoingLeaderboard)
        .where(filter)
    else
      policy_scope(Leaderboard)
        .where(filter)
    end
    if following?
      following_ids = current_participant.following.pluck(:followable_id)
      @leaderboards = @leaderboards.where(submitter_id: following_ids)
      @following    = true
    end
  end

  def paginate_leaderboards_by(order)
    @leaderboards.page(params[:page]).per(10).order(order)
  end

  def set_filter_service
    @filter = Leaderboards::FilterService.new(leaderboards: @leaderboards, params: params)
  end

  def submitter_submissions(submitter)
    @challenge.meta_challenge? ? submitter.meta_challenge_submissions(@challenge) : submitter.challenge_submissions(@challenge)
  end

  def is_disentanglement_leaderboard?(leaderboard)
    leaderboard.class.name == 'DisentanglementLeaderboard'
  end

  def freeze_record_for_organizer
    return false unless @current_round&.freeze_flag

    (policy(@challenge).edit? || current_participant&.admin)
  end
end
