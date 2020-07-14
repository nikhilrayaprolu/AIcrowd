class ParticipantMlChallengeGoal < ApplicationRecord
  belongs_to :participant, class_name: 'Participant'
  belongs_to :challenge, class_name: 'challenge'
  belongs_to :daily_practice_goal, class_name: 'DailyPracticeGoal'
end
