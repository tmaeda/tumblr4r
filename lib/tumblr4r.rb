require 'net/http'
require 'rubygems'
require 'rexml/document'
require 'active_support'
require 'logger'
require 'cgi'
module Tumblr4r
  VERSION = '0.7.2'
  class TumblrError < StandardError
    attr_accessor :attachment
    def initialize(msg, attachment=nil)
      super(msg)
      @attachment = attachment
    end
  end

  module POST_TYPE
    REGULAR = "regular"
    PHOTO = "photo"
    QUOTE = "quote"
    LINK = "link"
    CHAT = "conversation"
    AUDIO = "audio"
    VIDEO = "video"
  end

  # ConnectionオブジェクトとParserオブジェクトを組み合わせて、
  # TumblrAPIとRubyオブジェクトの相互変換を行う
  # TODO: private な post だけを取得する API が無いのだなぁ
  # * Webから更新したものがAPIで取得できるデータに反映されるには少しタイムラグがあるようだ
  # * Webから更新しちゃうと、POST日時の秒が丸められてしまう
  class Site
    attr_accessor :hostname, :email, :password, :name, :timezone, :title, :cname,
    :description, :feeds
    attr_accessor :logger
    # TODO: 変数名もうちょっと考える
    API_READ_LIMIT = 50
    @@default_log_level = Logger::INFO
    cattr_accessor :default_log_level

    class << self
      # TODO: unit test
      def find(hostname, email=nil, password=nil, http=nil, &block)
        site = self.new(hostname, email, password, http)
        result = site.find(:all)
        if block_given?
          result.each do |post|
            yield post
          end
        else
          return result
        end
      end
    end

    def initialize(hostname, email=nil, password=nil, http = nil, logger = nil)
      @hostname = hostname
      @email = email
      @password = password
      @logger = logger || Logger.new(STDERR)
      @logger.level = @@default_log_level
      @conn = XMLConnection.new(http || @hostname, email, password, @logger)
      @parser = XMLParser.new
      self.site_info
    end

    # TODO: ここの再帰取得ロジックはTumblrAPIとは独立してるので
    # TumblrAPIとは独立した形に切り出したり、TumblrAPIとは切り離してテストを書きたいものだ
    # @param [Symbol|Integer] id_or_type :all, id
    # @return [Array<Post>|Post]
    def find(id_or_type, options = { })
      params = { }
      return result if options[:offset] && options[:offset].to_i < 0
      [:type, :filter, :tagged, :search].each do |option|
        params[option] = options[option] if options[option]
      end

      if id_or_type == :all
        result = []
        # 取得開始位置の初期化
        params[:start] = options[:offset] || 0
        # goal の設定
        total = self.count(options)
        if options[:limit]
          goal = [total - params[:start],
                  options[:limit]].min
        else
          goal = total - params[:start]
        end
        # 取得件数の初期化
        if goal < 0
          return result
        elsif goal < API_READ_LIMIT
          params[:num] = goal
        else
          params[:num] = API_READ_LIMIT # :num を指定しないとデフォルトでは20件しかとれない
        end

        loop do
          xml = @conn.get(params)
          posts, start, total = @parser.posts(xml)
          @logger.info("size: #{posts.size}")
          @logger.info("start: #{start}")
          @logger.info("total: #{total}")
          result += posts
          if result.size >= goal || posts.size == 0
            # Tumblr API の total で得られる値は全く信用ならない。
            # 検索条件を考慮した件数を返してくれない。
            # (つまり、goalは信用ならない)ので、posts.sizeも終了判定に利用する。
            # TODO: もしくは:numの値を足し合わせていって、それとgoalを比較する？
            break
          end
          # 取得開始位置の調整
          params[:start] += params[:num]
          # 取得件数の調整
          if (goal - result.size) >= API_READ_LIMIT
            params[:num] = API_READ_LIMIT
          else
            params[:num] = goal - result.size
          end
        end
        return result
      elsif id_or_type.kind_of?(Integer)
        xml = @conn.get({:id => id_or_type})
        posts, start, total = @parser.posts(xml)
        @logger.info("size: #{posts.size}")
        @logger.info("start: #{start}")
        @logger.info("total: #{total}")
        return posts[0]
      else
        raise ArgumentError.new("id_or_type must be :all or Integer, but was #{id_or_type}(<#{id_or_type.class}>)")
      end
    end

    def count(options = { })
      params = { }
      [:id, :type, :filter, :tagged, :search].each do |option|
        params[option] = options[option] if options[option]
      end
      params[:num] = 1
      params[:start] = 0
      xml = @conn.get(params)
      posts, start, total = @parser.posts(xml)
      return total
    end

    def site_info
      xml = @conn.get(:num => 1)
      @parser.siteinfo(self, xml)
    end

    def save(post)
      post_id = @conn.write(post.params)
      new_post = self.find(post_id)
      return new_post
    end

    # @param [Integer|Post] post_id_or_post
    def delete(post_id_or_post)
      post_id = nil
      case post_id_or_post
      when Tumblr4r::Post
        post_id = post_id_or_post.post_id
      when Integer
        post_id = post_id_or_post
      else
        raise ArgumentError.new("post_id_or_post must be Tumblr4r::Post or Integer, but was #{post_id_or_post}(<#{post_id_or_post.class}>)")
      end
      return @conn.delete(post_id)
    end

  end

  # Postおよびその子クラスは原則として単なるData Transfer Objectとし、
  # 何かのロジックをこの中に実装はしない。
  class Post
    attr_accessor :post_id, # Integer
    :url, # String
    :url_with_slug, # String
    :type, # String
    :date_gmt,
    :date,
    :unix_timestamp, # Integer
    :format, # String("html"|"markdown")
    :tags, # Array<String>
    :bookmarklet, # true|false
    :private, # Integer(0|1)
    :generator # String

    @@default_generator = nil
    cattr_accessor :default_generator

    def initialize
      @generator = @@default_generator || "Tumblr4R"
      @tags = []
    end

    def params
      {"type" => @type,
        "generator" => @generator,
        "date" => @date,
        "private" => @private,
        "tags" => @tags.join(","),
        "format" => @format
      }
    end
  end

  class Regular < Post
    attr_accessor :regular_title, :regular_body

    def params
      super.merge!({"title" => @regular_title, "body" => @regular_body })
    end
  end

  # TODO: Feed の扱いをどうするか
  class Feed < Post
    attr_accessor  :regular_body, :feed_item, :from_feed_id
    # TODO: titleのあるfeed itemってあるのか？
  end

  class Photo < Post
    attr_accessor :photo_caption, :photo_link_url, :photo_url, :photoset
    #TODO: photo_url の max-width って何？
    attr_accessor :data

    # TODO: data をどうやってPOSTするか考える
    # 生のデータを持たせるんじゃなく、TumblrPostDataみたいな
    # クラスにラップして、それを各POSTのivarに保持させる？
    def params
      super.merge!(
                   {"source" => @photo_url,
                     "caption" => @photo_caption,
                     "click-through-url" => @photo_link_url,
                     "photoset" => @photoset,
                     "data" => @data})
    end
  end

  class Quote < Post
    attr_accessor :quote_text, :quote_source

    def params
      super.merge!(
                   {"quote" => @quote_text,
                     "source" => @quote_source})
    end
  end

  class Link < Post
    attr_accessor :link_text, :link_url, :link_description
    def params
      super.merge!(
                   {"name" => @link_text,
                     "url" => @link_url,
                     "description" => @link_description})
    end
  end

  class Chat < Post
    attr_accessor :conversation_title, :conversation_text
    # <conversation><line name="..." label="...">text</line>のリスト</conversation>

    def params
      super.merge!(
                   {"title" => @conversation_title,
                     "conversation" => @conversation_text})
    end
  end

  class Audio < Post
    attr_accessor :audio_plays, :audio_caption, :audio_player
    attr_accessor :data

    def params
      super.merge!(
                   {"data" => @data,
                     "caption" => @audio_caption})
    end
  end

  class Video < Post
    attr_accessor :video_caption, :video_source, :video_player
    attr_accessor :data, :title
    # TODO: title は vimeo へのアップロードのときのみ有効らしい
    # TODO: embed を使うか、アップロードしたdataを使うかってのは
    # Tumblr側で勝手に判断されるのかなぁ？
    def params
      super.merge!(
                   {"embed" => @video_source,
                     "data" => @data,
                     "title" => @title,
                     "caption" => @video_caption})
    end
  end

  # Tumblr XML API への薄いラッパー。
  # Rubyオブジェクトからの変換やRubyオブジェクトへの変換などは
  # Parserクラスで行う。Parserクラスへの依存関係は一切持たない。
  class XMLConnection
    attr_accessor :logger, :group, :authenticated
    def initialize(http_or_hostname, email=nil, password=nil, logger = nil)
      case http_or_hostname
      when String
        @conn = Net::HTTP.new(http_or_hostname)
      when Net::HTTP
        @conn = http_or_hostname
      else
        raise ArgumentError.new("http_or_hostname must be String or Net::HTTP but is #{http_or_hostname.class}")
      end
      @email= email
      @password = password
      if @email && @password
        begin
          @authenticated = authenticate
        rescue TumblrError
          @authenticated = false
        end
      end
      @group = @conn.address
      @logger = logger || Logger.new(STDERR)
    end

    # @param [Hash] options :id, :type, :filter, :tagged, :search, :start, :num
    def get(options = { })
      params = options.map{|k, v|
        "#{k}=#{v}"
      }.join("&")
      req = "/api/read?#{params}"
      logger.info(req)
      res = @conn.get(req)
      logger.debug(res.body)
      case res
      when Net::HTTPOK
        return res.body
      when Net::HTTPNotFound
        raise TumblrError.new("no such site(#{@hostname})", res)
      else
        raise TumblrError.new("unexpected response #{res.inspect}", res)
      end
    end

    # @return true if email and password are valid
    # @raise TumblrError if email or password is invalid
    def authenticate
      response = nil
      http = Net::HTTP.new("www.tumblr.com")
      response = http.post('/api/authenticate',
                           "email=#{CGI.escape(@email)}&password=#{CGI.escape(@password)}")

      case response
      when Net::HTTPOK
        return true
      else
        raise TumblrError.new(format_error(response), response)
      end
    end

    # @return [Integer] post_id if success
    # @raise [TumblrError] if fail
    def write(options)
      raise TumblrError.new("email or password is invalid") unless authenticated

      response = nil
      http = Net::HTTP.new("www.tumblr.com")
      params = options.merge({"email" => @email, "password" => @password, "group" => @group})
      query_string = params.delete_if{|k,v| v == nil }.map{|k,v| "#{k}=#{CGI.escape(v.to_s)}" unless v.nil?}.join("&")
      logger.debug("#### query_string: #{query_string}")
      response = http.post('/api/write', query_string)
      case response
      when Net::HTTPSuccess
        return response.body.to_i
      else
        raise TumblrError.new(format_error(response), response)
      end
    end

    # @param [Integer] post_id
    def delete(post_id)
      raise TumblrError.new("email or password is invalid") unless authenticated
      response = nil
      http = Net::HTTP.new("www.tumblr.com")
      params = {"post-id" => post_id, "email" => @email, "password" => @password, "group" => @group}
      query_string = params.delete_if{|k,v| v == nil }.map{|k,v| "#{k}=#{CGI.escape(v.to_s)}" unless v.nil?}.join("&")
      logger.debug("#### query_string: #{query_string}")
      response = http.post('/api/delete', query_string)
      case response
      when Net::HTTPSuccess
        logger.debug("#### response: #{response.code}: #{response.body}")
        return true
      else
        raise TumblrError.new(format_error(response), response)
      end
    end

    def format_error(http_response)
      msg = response.inspect + "\n"
      response.each{|k,v| msg += "#{k}: #{v}\n"}
      msg += response.body
      msg
    end
  end

  # Tumblr XML API
  class XMLParser
    # @param [Site] site xmlをパースした結果を埋める入れ物
    # @param [String] xml TumblrAPIのレスポンスのXMLそのまま
    def siteinfo(site, xml)
      xml_doc = REXML::Document.new(xml)
      tumblelog = REXML::XPath.first(xml_doc, "//tumblr/tumblelog")
      site.name = tumblelog.attributes["name"]
      site.timezone = tumblelog.attributes["timezone"]
      site.title = tumblelog.attributes["title"]
      site.cname = tumblelog.attributes["cname"]
      site.description = tumblelog.text
      # tumblelog.elements["/feeds"]}
      # TODO: feeds は後回し
      return site
    end

    # XMLをパースしてオブジェクトのArrayを作る
    # @param [String] xml APIからのレスポンス全体
    # @return [Array<Post>, Integer, Integer] 各種Postの子クラスのArray, start, total
    def posts(xml)
      rexml_doc = REXML::Document.new(xml)
      rexml_posts = REXML::XPath.first(rexml_doc, "//tumblr/posts")
      start = rexml_posts.attributes["start"]
      total = rexml_posts.attributes["total"]
      posts = []
      rexml_posts.elements.each("//posts/post") do |rexml_post|
        post_type = rexml_post.attributes["type"]
        post = nil
        case post_type
        when POST_TYPE::REGULAR
          post = self.regular(Regular.new, rexml_post)
        when POST_TYPE::PHOTO
          post = self.photo(Photo.new, rexml_post)
        when POST_TYPE::QUOTE
          post = self.quote(Quote.new, rexml_post)
        when POST_TYPE::LINK
          post = self.link(Link.new, rexml_post)
        when POST_TYPE::CHAT
          post = self.chat(Chat.new, rexml_post)
        when POST_TYPE::AUDIO
          post = self.audio(Audio.new, rexml_post)
        when POST_TYPE::VIDEO
          post = self.video(Video.new, rexml_post)
        else
          raise TumblrError.new("unknown post type #{post_type}")
        end
        posts << post
      end
      return posts, start.to_i, total.to_i
    end

    # TODO: この辺りの設計についてはもう少し考慮の余地がある？
    # みんな同じような構造(まずはpost(post, rexml_post)呼んでその後独自処理)してるし、
    # 引数にpostとrexml_postをもらってくるってのもなんかイケてない気がする。
    def post(post, rexml_post)
      post.post_id = rexml_post.attributes["id"].to_i
      post.url = rexml_post.attributes["url"]
      post.url_with_slug = rexml_post.attributes["url-with-slug"]
      post.type = rexml_post.attributes["type"]
      # TODO: time 関係の型をStringじゃなくTimeとかにする？
      post.date_gmt = rexml_post.attributes["date-gmt"]
      post.date = rexml_post.attributes["date"]
      post.unix_timestamp = rexml_post.attributes["unix-timestamp"].to_i
      post.format = rexml_post.attributes["format"]
      post.tags = rexml_post.get_elements("tag").map(&:text)
      post.bookmarklet = (rexml_post.attributes["bookmarklet"] == "true")
      post
    end

    def regular(post, rexml_post)
      post = self.post(post, rexml_post)
      post.regular_title = rexml_post.elements["regular-title"].try(:text) || ""
      post.regular_body = rexml_post.elements["regular-body"].try(:text) || ""
      post
    end

    def photo(post, rexml_post)
      post = self.post(post, rexml_post)
      post.type
      post.photo_caption = rexml_post.elements["photo-caption"].try(:text) || ""
      post.photo_link_url = rexml_post.elements["photo-link-url"].try(:text) || ""
      post.photo_url = rexml_post.elements["photo-url"].try(:text) || ""
      post.photoset = []
      rexml_post.elements.each("photoset/photo") do |photo|
        post.photoset.push(photo.elements["photo-url"].try(:text) || "")
      end
      post
    end

    def quote(post, rexml_post)
      post = self.post(post, rexml_post)
      post.quote_text = rexml_post.elements["quote-text"].try(:text) || ""
      post.quote_source = rexml_post.elements["quote-source"].try(:text) || ""
      post
    end

    def link(post, rexml_post)
      post = self.post(post, rexml_post)
      post.link_text = rexml_post.elements["link-text"].try(:text) || ""
      post.link_url = rexml_post.elements["link-url"].try(:text) || ""
      post.link_description = rexml_post.elements["link-description"].try(:text) || ""
      post
    end

    def chat(post, rexml_post)
      post = self.post(post, rexml_post)
      post.conversation_title = rexml_post.elements["conversation-title"].try(:text) || ""
      post.conversation_text = rexml_post.elements["conversation-text"].try(:text) || ""
      post
    end

    def audio(post, rexml_post)
      post = self.post(post, rexml_post)
      post.audio_plays = (rexml_post.attributes["audio-plays"] == "1")
      post.audio_caption = rexml_post.elements["audio-caption"].try(:text) || ""
      post.audio_player = rexml_post.elements["audio-player"].try(:text) || ""
      post
    end

    def video(post, rexml_post)
      post = self.post(post, rexml_post)
      post.video_caption = rexml_post.elements["video-caption"].try(:text) || ""
      post.video_source = rexml_post.elements["video-source"].try(:text) || ""
      post.video_player = rexml_post.elements["video-player"].try(:text) || ""
      post
    end

  end

end # module
