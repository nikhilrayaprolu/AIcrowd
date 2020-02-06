class RemoveLeaderboardsMaterializedViews < ActiveRecord::Migration[5.2]
  def change
    drop_view :leaderboards
  end
end
