module IceCube
  VERSION = '0.1'

  ICAL_DAYS = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']
  DAYS = { :sunday => 0, :monday => 1, :tuesday => 2, :wednesday => 3, :thursday => 4, :friday => 5, :saturday => 6 }
  MONTHS = { :january => 1, :february => 2, :march => 3, :april => 4, :may => 5, :june => 6, :july => 7, :august => 8, 
             :september => 9, :october => 10, :november => 11, :december => 12 }
end

require 'yaml.rb'
require 'set.rb'

require 'ice_cube/rule'
require 'ice_cube/schedule'
require 'ice_cube/rule_occurrence'

#date-related rules
require 'ice_cube/daily_rule'
require 'ice_cube/weekly_rule'
require 'ice_cube/monthly_rule'
require 'ice_cube/yearly_rule'
    
ONE_DAY = 24 * 60 * 60
    
class Time
  
  LeapYearMonthDays	=	[31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  CommonYearMonthDays	=	[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  
  def is_leap?
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
  end
  
  def days_in_year
    is_leap? ? 366 : 365
  end
  
  def days_in_month
    is_leap? ? LeapYearMonthDays[month - 1] : CommonYearMonthDays[month - 1]
  end
  
  #todo - there might be another optimization here - think about the possibility of incorporating these in the walks
  #TODO - combine the two methods below into one
  #todo - there might be a way to sort on insert in all of these, which would remove the need for map (negatives are a definite issue)
  # todo - play with the idea of next_occurrence to replace occurs_on? for individual rules
  # todo - make interval jump suggestions == maybe we don't use suggestions, we incorporate this into rules instead

  def closest_day_of_year(days_of_year)
    #get some variables we need
    days_left_in_this_year = days_in_year - yday
    days_in_next_year = Time.utc(year + 1, 1, 1).days_in_year
    # create a list of distances
    distances = []
    days_of_year.each do |d|
      if d > 0
        distances << d - yday #today is 1, we want 20 (19)
        distances << days_left_in_this_year + d #(364 + 20)
      elsif d < 0
        distances << (days_in_year + d + 1) - yday #today is 300, we want -1
        distances << (days_in_next_year + d + 1) + days_left_in_this_year #today is 300, we want -70
      end
    end
    #return the lowest distance
    distances = distances.select { |d| d > 0 }
    distances.empty? ? nil : self + distances.min * ONE_DAY
  end
  
  def closest_day_of_month(days_of_month)
    #get some variables we need
    days_left_in_this_month = days_in_month - mday
    next_month, next_year = month == 12 ? [1, year + 1] : [month + 1, year] #clean way to wrap over years
    days_in_next_month = Time.utc(next_year, next_month, 1).days_in_month
    # create a list of distances
    distances = []
    days_of_month.each do |d|
      if d > 0
        distances << d - mday #today is 1, we want 20 (19)
        distances << days_left_in_this_month + d #(364 + 20)
      elsif d < 0
        distances << (days_in_month + d + 1) - mday #today is 30, we want -1
        distances << (days_in_next_month + d + 1) + days_left_in_this_month #today is 300, we want -70
      end
    end
    #return the lowest distance
    distances = distances.select { |d| d > 0 }
    distances.empty? ? nil : self + distances.min * ONE_DAY
  end
  
  # return the date object corresponding to the first day of the closest month
  def closest_month_of_year(months_of_year)
    #add 12 to all of the months that are less than this month
    return nil if months_of_year.empty?
    months = months_of_year.map { |m| m <= month ? m + 12 : m }.sort!
    #return the proper first day in months[0]
    if months[0] > 12
      Time.utc(year + 1, months[0] - 12, 1)
    else
      Time.utc(year, months[0], 1)
    end
  end
  # dow wday d   
  # [2] 1 => 2 = 2 - 1
  # [2] 5 => 2 = 7 - 5 + 2
  # [2] 2 => 2 = 7 - 2 + 2
  # [2] 3 => 1 = 7 - 3 + 1
  
  
  #TODO - don't generate days here anymore, just generate DIFFs (if possible)

  def closest_day_of_week(days_of_week)
    #determine how far away the days we want are from where we're at now
    return nil if days_of_week.empty?
    days = days_of_week.map { |d| d <= wday ? d + 7 : d }.sort!
    # return the proper next of this weekday
    self + (days[0] - wday) * ONE_DAY
  end

end