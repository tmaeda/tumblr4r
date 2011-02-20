require File.dirname(__FILE__) + '/test_helper.rb'
require "test/unit"
require 'pit'
require 'pp'
$KCODE='u'
class Tumblr4rDashboardTest < Test::Unit::TestCase
  include Tumblr4r
  DASHBOARD_TEST_HOST = "tumblr4r-dashboard-test.tumblr.com"
  TOTAL_COUNT = 123
  REGULAR_COUNT = 6
  QUOTE_COUNT = 103
  PHOTO_COUNT = 2

  def setup
    Site.default_log_level = Logger::DEBUG
    auth_info = Pit.get("tumblr4r-dashbard-test",
                             :require => {"email" => "required email",
                             "password" => "required password"})
    @site = Site.new(DASHBOARD_TEST_HOST,
                     auth_info["email"],
                     auth_info["password"])
  end

  def teardown
  end
=begin
  def test_find_all
    posts = @site.dashboard
    pp posts
    assert_equal TOTAL_COUNT, posts.size
  end
=end
  def test_type
    posts = @site.dashboard(:type => "regular")
    assert_equal REGULAR_COUNT, posts.size
    assert posts.all?{|p| p.type == Tumblr4r::POST_TYPE::REGULAR }

    posts = @site.dashboard(:type => "quote")
    assert_equal QUOTE_COUNT, posts.size
    assert posts.all?{|p| p.type == Tumblr4r::POST_TYPE::QUOTE }

    posts = @site.dashboard(:type => "photo")
    assert_equal PHOTO_COUNT, posts.size
    assert posts.all?{|p| p.type == Tumblr4r::POST_TYPE::PHOTO }
  end
end
