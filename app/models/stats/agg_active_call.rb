# == Schema Information
#
# Table name: stats.active_calls_hourly
#
#  id         :integer          not null, primary key
#  node_id    :integer          not null
#  max_count  :integer          not null
#  avg_count  :float            not null
#  min_count  :integer          not null
#  created_at :datetime         not null
#  calls_time :datetime         not null
#

class Stats::AggActiveCall < Stats::Base
  self.table_name = "stats.active_calls_hourly"

  include ::AggChart
   self.chart_entity_column = :node_id


end
