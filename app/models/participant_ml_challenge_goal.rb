class ParticipantMlChallengeGoal < ApplicationRecord
  belongs_to :participant, class_name: 'Participant'
  belongs_to :challenge
  belongs_to :daily_practice_goal
end
