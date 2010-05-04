require File.dirname(__FILE__) + '/test_helper.rb'
require "test/unit"
require 'pit'
class Tumblr4rTest < Test::Unit::TestCase
  include Tumblr4r
  READ_TEST_HOST = "tumblr4rtest.tumblr.com"
  WRITE_TEST_HOST = "tumblr4rwritetest.tumblr.com"
  TOTAL_COUNT = 114
  QUOTE_COUNT = 102

  def setup
    @site = Site.new(READ_TEST_HOST)
    writetest_conf = Pit.get("tumblr4rwritetest",
                             :require => {"email" => "required email",
                             "password" => "required password"})
    @write_site = Site.new(WRITE_TEST_HOST,
                           writetest_conf["email"],
                           writetest_conf["password"])
    @large_site = Site.new("tumblr4rfindtest.tumblr.com")
  end

  def teardown
  end

  def test_initialize
    assert_equal READ_TEST_HOST, @site.hostname
    assert_nil @site.email
    assert_nil @site.password

    assert_equal "tumblr4rtest", @site.name
    assert_equal "Asia/Tokyo", @site.timezone
    assert_equal "tumblr4rテスト", @site.title
    assert_nil @site.cname
    assert_equal "tumblr4rのテスト用サイトです。\r\ntumblrサイコー", @site.description
    # TODO: feeds は後回し
  end

  def test_count
    total = @large_site.count
    assert_equal TOTAL_COUNT, total

    total = @large_site.count(:type => "quote")
    assert_equal QUOTE_COUNT, total

    total = @large_site.count(:filter => "text")
    assert_equal TOTAL_COUNT, total

    total = @large_site.count(:tagged => "test")
    assert_equal TOTAL_COUNT, total

    total = @large_site.count(:search => "test")
    assert_equal TOTAL_COUNT, total
  end

  def test_find
    posts = @site.find(:all)
    assert_equal 9, posts.size
    assert_equal Photo, posts[0].class
  end

  def test_find_all
    posts = @large_site.find(:all)
    assert_equal TOTAL_COUNT, posts.size
  end

  def test_find_all_quote
    posts = @large_site.find(:all, :type => "quote")
    assert_equal QUOTE_COUNT, posts.size
  end

  # 実際に存在する件数より少なく指定した場合
  def test_find_all_with_num
    posts = @large_site.find(:all, :limit => 74)
    assert_equal 74, posts.size
  end

  # 実際に存在する件数より多く指定した場合
  def test_find_all_with_over_num
    posts = @large_site.find(:all, :limit => 765)
    assert_equal TOTAL_COUNT, posts.size
  end

  def test_find_all_with_offset
    posts = @large_site.find(:all, :offset => 12)
    assert_equal TOTAL_COUNT-12, posts.size
  end

  def test_find_all_with_limit_and_offset
    posts = @large_site.find(:all, :offset => 1, :limit => 2)
    assert_equal 2, posts.size
  end

  # 実際に存在するよりも多いoffsetを指定した場合
  def test_find_all_over_offset
    posts = @large_site.find(:all, :type => "quote", :offset => TOTAL_COUNT + 1)
    assert_equal 0, posts.size
  end

  def test_find_with_type_regular
    posts = @site.find(:all, :type => "regular")
    assert_equal 2, posts.size

    assert_equal Regular, posts[0].class
    assert_equal 123459291, posts[0].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/123459291", posts[0].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/123459291/regular-test", posts[0].url_with_slug
    assert_equal "regular", posts[0].type
    assert_equal "2009-06-14 16:30:44 GMT", posts[0].date_gmt
    assert_equal "Mon, 15 Jun 2009 01:30:44", posts[0].date
    assert_equal 1244997044, posts[0].unix_timestamp
    assert_equal "html", posts[0].format
    assert_equal ["test", "regular"], posts[0].tags
    assert_equal false, posts[0].bookmarklet

    assert_equal "Text Postのテストです", posts[0].regular_title
    assert_equal <<EOF.chomp, posts[0].regular_body
<p>テキストです。</p>
<p><b>ボールドです。</b></p>
<p><i>イタリックです。</i></p>
<p><strike>取り消し線です。</strike></p>
<ul>
<li>unordered 1</li>
<li>unordered 2</li>
</ul>
<ol>
<li>ordered 1</li>
<li>ordered 2</li>
</ol>
<p>ここからインデント</p>
<blockquote style="margin: 0 0 0 40px; border: none; padding: 0px;">インデント開始<br/>ああああ<br/>インデント終了</blockquote>
<p>ここまでインデント</p>
EOF

    assert_equal Regular, posts[1].class
    assert_equal 122871637, posts[1].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/122871637", posts[1].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/122871637/tumblr4r", posts[1].url_with_slug
    assert_equal "regular", posts[1].type
    assert_equal "2009-06-13 12:46:23 GMT", posts[1].date_gmt
    assert_equal "Sat, 13 Jun 2009 21:46:23", posts[1].date
    assert_equal 1244897183, posts[1].unix_timestamp
    assert_equal "html", posts[1].format
    assert_equal [], posts[1].tags
    assert_equal false, posts[1].bookmarklet

    assert_equal "", posts[1].regular_title
    assert_equal "<p>Tumblr4rのテストです</p>", posts[1].regular_body
  end

  def test_find_with_type_photo
    posts = @site.find(:all, :type => "photo")
    assert_equal 2, posts.size

    # normal
    assert_equal Photo, posts[1].class
    assert_equal 123461063, posts[1].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/123461063", posts[1].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/123461063/photo", posts[1].url_with_slug
    assert_equal "photo", posts[1].type
    assert_equal "2009-06-14 16:34:50 GMT", posts[1].date_gmt
    assert_equal "Mon, 15 Jun 2009 01:34:50", posts[1].date
    assert_equal 1244997290, posts[1].unix_timestamp
    assert_equal "html", posts[1].format
    assert_equal ["test", "photo"], posts[1].tags
    assert_equal false, posts[1].bookmarklet

    assert_equal "<p>Photoのテストです。</p>\n\n<p>ギコです。</p>", posts[1].photo_caption
    assert_equal "http://www.google.co.jp/", posts[1].photo_link_url
    assert_equal "http://5.media.tumblr.com/GyEYZujUYopiula4XKmXhCgmo1_250.jpg", posts[1].photo_url
    assert_equal [], posts[1].photoset

    # photoset
    assert_equal Photo, posts[0].class
    assert_equal 211868268, posts[0].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/211868268", posts[0].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/211868268/photoset-test", posts[0].url_with_slug
    assert_equal "photo", posts[0].type
    assert_equal "2009-10-13 10:19:04 GMT", posts[0].date_gmt
    assert_equal "Tue, 13 Oct 2009 19:19:04", posts[0].date
    assert_equal 1255429144, posts[0].unix_timestamp
    assert_equal "html", posts[0].format
    assert_equal [], posts[0].tags
    assert_equal false, posts[0].bookmarklet

    assert_equal "Photoset test.", posts[0].photo_caption
    assert_equal "", posts[0].photo_link_url
    assert_equal "http://22.media.tumblr.com/tumblr_krg7btBOD21qzfaavo1_250.jpg", posts[0].photo_url
    assert_equal ["http://22.media.tumblr.com/tumblr_krg7btBOD21qzfaavo1_250.jpg",
                 "http://6.media.tumblr.com/tumblr_krg7btBOD21qzfaavo2_500.jpg",
                 "http://16.media.tumblr.com/tumblr_krg7btBOD21qzfaavo3_500.png"], posts[0].photoset

  end

  def test_find_with_type_quote
    posts = @site.find(:all, :type => "quote")
    assert_equal 1, posts.size
    assert_equal Quote, posts[0].class
    assert_equal 123470309, posts[0].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/123470309", posts[0].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/123470309/wikipedia-tumblr", posts[0].url_with_slug
    assert_equal "quote", posts[0].type
    assert_equal "2009-06-14 16:58:00 GMT", posts[0].date_gmt
    assert_equal "Mon, 15 Jun 2009 01:58:00", posts[0].date
    assert_equal 1244998680, posts[0].unix_timestamp
    assert_equal "html", posts[0].format
    assert_equal ["quote", "test"], posts[0].tags
    assert_equal true, posts[0].bookmarklet

    assert_equal <<EOF.chomp, posts[0].quote_text
Tumblelog/Tumblr（タンブルログ/タンブラー）は、メディアミックスウェブログサービス。米国 Davidville.incにより2007年3月1日にサービスが開始された。
EOF
    assert_equal "<a href=\"http://ja.wikipedia.org/wiki/Tumblr\">Tumblelog - Wikipedia</a>", posts[0].quote_source
  end

  def test_find_with_type_link
    posts = @site.find(:all, :type => "link")
    assert_equal 1, posts.size
    assert_equal Link, posts[0].class
    assert_equal 123470990, posts[0].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/123470990", posts[0].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/123470990/tumblr-link", posts[0].url_with_slug
    assert_equal "link", posts[0].type
    assert_equal "2009-06-14 17:00:00 GMT", posts[0].date_gmt
    assert_equal "Mon, 15 Jun 2009 02:00:00", posts[0].date
    assert_equal 1244998800, posts[0].unix_timestamp
    assert_equal "html", posts[0].format
    assert_equal ["test", "link"], posts[0].tags
    assert_equal false, posts[0].bookmarklet

    assert_equal "たんぶらー", posts[0].link_text
    assert_equal "http://www.tumblr.com/", posts[0].link_url
    assert_equal "<p>ですくりぷしょん</p>", posts[0].link_description
  end

  def test_find_with_type_conversation
    posts = @site.find(:all, :type => "conversation")
    assert_equal 1, posts.size
    assert_equal Chat, posts[0].class
    assert_equal 123471808, posts[0].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/123471808", posts[0].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/123471808/pointcard-chat", posts[0].url_with_slug
    assert_equal "conversation", posts[0].type
    assert_equal "2009-06-14 17:01:54 GMT", posts[0].date_gmt
    assert_equal "Mon, 15 Jun 2009 02:01:54", posts[0].date
    assert_equal 1244998914, posts[0].unix_timestamp
    assert_equal "html", posts[0].format
    assert_equal ["test", "chat"], posts[0].tags
    assert_equal false, posts[0].bookmarklet

    assert_equal "なにそれこわい", posts[0].conversation_title
    assert_equal <<EOF.chomp, posts[0].conversation_text
店員: 当店のポイントカードはお餅でしょうか\r
ぼく: えっ\r
店員: 当店のポイントカードはお餅ですか \r
ぼく: いえしりません\r
店員: えっ\r
ぼく: えっ\r
EOF
  end

  def test_find_with_type_audio
    posts = @site.find(:all, :type => "audio")
    assert_equal 1, posts.size
    assert_equal Audio, posts[0].class
    assert_equal 131705561, posts[0].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/131705561", posts[0].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/131705561/tumblr4r-miku", posts[0].url_with_slug
    assert_equal "audio", posts[0].type
    assert_equal "2009-06-28 13:58:13 GMT", posts[0].date_gmt
    assert_equal "Sun, 28 Jun 2009 22:58:13", posts[0].date
    assert_equal 1246197493, posts[0].unix_timestamp
    assert_equal "html", posts[0].format
    assert_equal [], posts[0].tags
    assert_equal false, posts[0].bookmarklet

    assert_equal true, posts[0].audio_plays
    assert_equal "<p>tumblr4r miku</p>", posts[0].audio_caption
    assert_equal "<embed type=\"application/x-shockwave-flash\" src=\"http://tumblr4rtest.tumblr.com/swf/audio_player.swf?audio_file=http://www.tumblr.com/audio_file/131705561/GyEYZujUYp9df3nv1WMefTH8&color=FFFFFF\" height=\"27\" width=\"207\" quality=\"best\"></embed>", posts[0].audio_player
  end

  def test_find_with_type_video
    posts = @site.find(:all, :type => "video")
    assert_equal 1, posts.size
    assert_equal Video, posts[0].class
    assert_equal 131714219, posts[0].post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/131714219", posts[0].url
    assert_equal "http://tumblr4rtest.tumblr.com/post/131714219/matrix-sappoloaded", posts[0].url_with_slug
    assert_equal "video", posts[0].type
    assert_equal "2009-06-28 14:22:56 GMT", posts[0].date_gmt
    assert_equal "Sun, 28 Jun 2009 23:22:56", posts[0].date
    assert_equal 1246198976, posts[0].unix_timestamp
    assert_equal "html", posts[0].format
    assert_equal [], posts[0].tags
    assert_equal false, posts[0].bookmarklet

    assert_equal "<p>matrix sappoloaded</p>", posts[0].video_caption
    assert_equal "http://www.youtube.com/watch?v=FavWH5RhYpw", posts[0].video_source
    assert_equal "<object width=\"400\" height=\"336\"><param name=\"movie\" value=\"http://www.youtube.com/v/FavWH5RhYpw&amp;rel=0&amp;egm=0&amp;showinfo=0&amp;fs=1\"></param><param name=\"wmode\" value=\"transparent\"></param><param name=\"allowFullScreen\" value=\"true\"></param><embed src=\"http://www.youtube.com/v/FavWH5RhYpw&amp;rel=0&amp;egm=0&amp;showinfo=0&amp;fs=1\" type=\"application/x-shockwave-flash\" width=\"400\" height=\"336\" allowFullScreen=\"true\" wmode=\"transparent\"></embed></object>", posts[0].video_player
  end

  def test_find_with_tagged
    posts = @site.find(:all, :tagged => "test")
    assert_equal 5, posts.size
  end

  def test_find_with_search
    posts = @site.find(:all, :search => "matrix")
    assert_equal 1, posts.size
  end

  def test_generator_default
    post = Post.new
    assert_equal "Tumblr4R", post.generator

    Post.default_generator = "foo"
    post2 = Post.new
    assert_equal "foo", post2.generator
    assert_equal "Tumblr4R", post.generator


    Post.default_generator = nil
    post3 = Post.new
    assert_equal "Tumblr4R", post3.generator
  end

  def test_find_by_id
    post = @site.find(123459291)

    assert_equal Regular, post.class
    assert_equal 123459291, post.post_id
    assert_equal "http://tumblr4rtest.tumblr.com/post/123459291", post.url
    assert_equal "http://tumblr4rtest.tumblr.com/post/123459291/regular-test", post.url_with_slug
    assert_equal "regular", post.type
    assert_equal "2009-06-14 16:30:44 GMT", post.date_gmt
    assert_equal "Mon, 15 Jun 2009 01:30:44", post.date
    assert_equal 1244997044, post.unix_timestamp
    assert_equal "html", post.format
    assert_equal ["test", "regular"], post.tags
    assert_equal false, post.bookmarklet

    assert_equal "Text Postのテストです", post.regular_title
    assert_equal <<EOF.chomp, post.regular_body
<p>テキストです。</p>
<p><b>ボールドです。</b></p>
<p><i>イタリックです。</i></p>
<p><strike>取り消し線です。</strike></p>
<ul>
<li>unordered 1</li>
<li>unordered 2</li>
</ul>
<ol>
<li>ordered 1</li>
<li>ordered 2</li>
</ol>
<p>ここからインデント</p>
<blockquote style="margin: 0 0 0 40px; border: none; padding: 0px;">インデント開始<br/>ああああ<br/>インデント終了</blockquote>
<p>ここまでインデント</p>
EOF
  end

  def test_quote_create
    quotes = @site.find(:all, :type => Tumblr4r::POST_TYPE::QUOTE)
    post = @write_site.save(quotes[0])
    assert_not_equal quotes[0].post_id, post.post_id
    assert_equal "http://#{WRITE_TEST_HOST}/post/#{post.post_id}", post.url
    assert_equal "http://#{WRITE_TEST_HOST}/post/#{post.post_id}/tumblelog-tumblr", post.url_with_slug
    assert_equal Tumblr4r::POST_TYPE::QUOTE, post.type
    assert_equal quotes[0].date_gmt, post.date_gmt
    assert_equal quotes[0].date, post.date
    # TODO
#    assert_equal 1245045480, post.unix_timestamp
    assert_equal quotes[0].format, post.format
    assert_equal quotes[0].tags, post.tags
    assert_equal false, post.bookmarklet

    assert_equal quotes[0].quote_text, post.quote_text
    assert_equal quotes[0].quote_source, post.quote_source
  end

  def test_regular_create
    regulars = @site.find(:all, :type => Tumblr4r::POST_TYPE::REGULAR)
    post = @write_site.save(regulars[0])
  end

  def test_link_create
    links = @site.find(:all, :type => Tumblr4r::POST_TYPE::LINK)
    post = @write_site.save(links[0])
  end

  def test_photo_create
    photos = @site.find(:all, :type => Tumblr4r::POST_TYPE::PHOTO)
    post = @write_site.save(photos[0])
  end


#  def test_audio_create
#    audios = @site.find(:all, :type => Tumblr4r::POST_TYPE::AUDIO)
#    post = @write_site.save(audios[0])
#  end

  def test_video_create
    videos = @site.find(:all, :type => Tumblr4r::POST_TYPE::VIDEO)
    post = @write_site.save(videos[0])
  end

end

