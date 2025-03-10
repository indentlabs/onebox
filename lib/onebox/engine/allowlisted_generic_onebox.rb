# frozen_string_literal: true

require 'htmlentities'

module Onebox
  module Engine
    class AllowlistedGenericOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      def self.priority
        200
      end

      def self.allowed_domains=(list)
        @allowed_domains = list
      end

      def self.allowed_domains
        @allowed_domains ||= default_allowed_domains.dup
      end

      def self.default_allowed_domains
        %w(
          23hq.com
          500px.com
          8tracks.com
          abc.net.au
          answers.com
          arstechnica.com
          ask.com
          battle.net
          bbc.co.uk
          bbs.boingboing.net
          bestbuy.ca
          bestbuy.com
          bloomberg.com
          businessinsider.com
          change.org
          cnet.com
          cnn.com
          codepen.io
          collegehumor.com
          consider.it
          coursera.org
          cracked.com
          dailymail.co.uk
          dailymotion.com
          deadline.com
          dell.com
          deviantart.com
          digg.com
          dotsub.com
          ebay.ca
          ebay.co.uk
          ebay.com
          ehow.com
          espn.go.com
          etsy.com
          facebook.com
          findery.com
          folksy.com
          forbes.com
          foxnews.com
          funnyordie.com
          gifs.com
          groupon.com
          howtogeek.com
          huffingtonpost.ca
          huffingtonpost.com
          hulu.com
          ign.com
          ikea.com
          imdb.com
          indiatimes.com
          itunes.apple.com
          khanacademy.org
          kickstarter.com
          kinomap.com
          lessonplanet.com
          linkedin.com
          liveleak.com
          livestream.com
          mashable.com
          medium.com
          meetup.com
          mixcloud.com
          mlb.com
          myspace.com
          nba.com
          notebook.ai
          npr.org
          nytimes.com
          photobucket.com
          pinterest.com
          reference.com
          rottentomatoes.com
          samsung.com
          scribd.com
          slideshare.net
          sourceforge.net
          speakerdeck.com
          spotify.com
          streamable.com
          techcrunch.com
          ted.com
          thefreedictionary.com
          theglobeandmail.com
          thenextweb.com
          theonion.com
          thestar.com
          thesun.co.uk
          thinkgeek.com
          tmz.com
          torontosun.com
          tumblr.com
          twitpic.com
          usatoday.com
          viddler.com
          vine.co
          walmart.com
          washingtonpost.com
          wi.st
          wikia.com
          wikihow.com
          wired.com
          wistia.com
          wonderhowto.com
          wsj.com
          zappos.com
          zillow.com
        )
      end

      # Often using the `html` attribute is not what we want, like for some blogs that
      # include the entire page HTML. However for some providers like Flickr it allows us
      # to return gifv and galleries.
      def self.default_html_providers
        ['Flickr', 'Meetup']
      end

      def self.html_providers
        @html_providers ||= default_html_providers.dup
      end

      def self.html_providers=(new_provs)
        @html_providers = new_provs
      end

      # A re-written URL converts http:// -> https://
      def self.rewrites
        @rewrites ||= https_hosts.dup
      end

      def self.rewrites=(new_list)
        @rewrites = new_list
      end

      def self.https_hosts
        %w(slideshare.net dailymotion.com livestream.com imgur.com flickr.com)
      end

      def self.host_matches(uri, list)
        !!list.find { |h| %r((^|\.)#{Regexp.escape(h)}$).match(uri.host) }
      end

      def self.probable_discourse(uri)
        !!(uri.path =~ /\/t\/[^\/]+\/\d+(\/\d+)?(\?.*)?$/)
      end

      def self.probable_wordpress(uri)
        !!(uri.path =~ /\d{4}\/\d{2}\//)
      end

      def self.allowed_twitter_labels
        ['brand', 'price', 'usd', 'cad', 'reading time', 'likes']
      end

      def self.===(other)
        other.kind_of?(URI) ?
          host_matches(other, allowed_domains) || probable_wordpress(other) || probable_discourse(other) :
          super
      end

      def to_html
        rewrite_https(generic_html)
      end

      def placeholder_html
        return article_html if is_article?
        return image_html if is_image?
        return Onebox::Helpers.video_placeholder_html if is_video? || is_card?
        return Onebox::Helpers.generic_placeholder_html if is_embedded?
        to_html
      end

      def data
        @data ||= begin
          html_entities = HTMLEntities.new
          d = { link: link }.merge(raw)

          if !Onebox::Helpers.blank?(d[:title])
            d[:title] = html_entities.decode(Onebox::Helpers.truncate(d[:title], 80))
          end

          d[:description] ||= d[:summary]
          if !Onebox::Helpers.blank?(d[:description])
            d[:description] = html_entities.decode(Onebox::Helpers.truncate(d[:description], 250))
          end

          if !Onebox::Helpers.blank?(d[:site_name])
            d[:domain] = html_entities.decode(Onebox::Helpers.truncate(d[:site_name], 80))
          elsif !Onebox::Helpers.blank?(d[:domain])
            d[:domain] = "http://#{d[:domain]}" unless d[:domain] =~ /^https?:\/\//
            d[:domain] = URI(d[:domain]).host.to_s.sub(/^www\./, '') rescue nil
          end

          # prefer secure URLs
          d[:image] = d[:image_secure_url] || d[:image_url] || d[:thumbnail_url] || d[:image]
          d[:image] = Onebox::Helpers::get_absolute_image_url(d[:image], @url)
          d[:image] = Onebox::Helpers::normalize_url_for_output(html_entities.decode(d[:image]))
          d[:image] = nil if Onebox::Helpers.blank?(d[:image])

          d[:video] = d[:video_secure_url] || d[:video_url] || d[:video]
          d[:video] = nil if Onebox::Helpers.blank?(d[:video])

          d[:published_time] = d[:article_published_time] unless Onebox::Helpers.blank?(d[:article_published_time])
          if !Onebox::Helpers.blank?(d[:published_time])
            d[:article_published_time] = Time.parse(d[:published_time]).strftime("%-d %b %y")
            d[:article_published_time_title] = Time.parse(d[:published_time]).strftime("%I:%M%p - %d %B %Y")
          end

          # Twitter labels
          if !Onebox::Helpers.blank?(d[:label1]) && !Onebox::Helpers.blank?(d[:data1]) && !!AllowlistedGenericOnebox.allowed_twitter_labels.find { |l| d[:label1] =~ /#{l}/i }
            d[:label_1] = Onebox::Helpers.truncate(d[:label1])
            d[:data_1]  = Onebox::Helpers.truncate(d[:data1])
          end
          if !Onebox::Helpers.blank?(d[:label2]) && !Onebox::Helpers.blank?(d[:data2]) && !!AllowlistedGenericOnebox.allowed_twitter_labels.find { |l| d[:label2] =~ /#{l}/i }
            unless Onebox::Helpers.blank?(d[:label_1])
              d[:label_2] = Onebox::Helpers.truncate(d[:label2])
              d[:data_2]  = Onebox::Helpers.truncate(d[:data2])
            else
              d[:label_1] = Onebox::Helpers.truncate(d[:label2])
              d[:data_1]  = Onebox::Helpers.truncate(d[:data2])
            end
          end

          if Onebox::Helpers.blank?(d[:label_1]) && !Onebox::Helpers.blank?(d[:price_amount]) && !Onebox::Helpers.blank?(d[:price_currency])
            d[:label_1] = "Price"
            d[:data_1] = Onebox::Helpers.truncate("#{d[:price_currency].strip} #{d[:price_amount].strip}")
          end

          skip_missing_tags = [:video]
          d.each do |k, v|
            next if skip_missing_tags.include?(k)
            if v == nil || v == ''
              errors[k] ||= []
              errors[k] << 'is blank'
            end
          end

          d
        end
      end

      private

      def rewrite_https(html)
        return unless html
        if AllowlistedGenericOnebox.host_matches(uri, AllowlistedGenericOnebox.rewrites)
          html = html.gsub("http://", "https://")
        end
        html
      end

      def generic_html
        return article_html  if is_article?
        return video_html    if is_video?
        return image_html    if is_image?
        return embedded_html if is_embedded?
        return card_html     if is_card?
        return article_html  if (has_text? || is_image_article?)
      end

      def is_card?
        data[:card] == 'player' &&
          data[:player] =~ URI::regexp &&
          options[:allowed_iframe_regexes]&.any? { |r| data[:player] =~ r }
      end

      def is_article?
        (data[:type] =~ /article/ || data[:asset_type] =~ /article/) &&
        has_text?
      end

      def has_text?
        has_title? && !Onebox::Helpers.blank?(data[:description])
      end

      def has_title?
        !Onebox::Helpers.blank?(data[:title])
      end

      def is_image_article?
        has_title? && has_image?
      end

      def is_image?
        data[:type] =~ /photo|image/ &&
        data[:type] !~ /photostream/ &&
        has_image?
      end

      def has_image?
        !Onebox::Helpers.blank?(data[:image])
      end

      def is_video?
        data[:type] =~ /^video[\/\.]/ &&
          data[:video_type] == "video/mp4" && # Many sites include 'videos' with text/html types (i.e. iframes)
          !Onebox::Helpers.blank?(data[:video])
      end

      def is_embedded?
        return false unless data[:html] && data[:height]
        return true if AllowlistedGenericOnebox.html_providers.include?(data[:provider_name])
        return false unless data[:html]["iframe"]

        fragment = Nokogiri::HTML5::fragment(data[:html])
        src = fragment.at_css('iframe')&.[]("src")
        options[:allowed_iframe_regexes]&.any? { |r| src =~ r }
      end

      def card_html
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(data[:player])

        <<~RAW
        <iframe src="#{escaped_url}"
                width="#{data[:player_width] || "100%"}"
                height="#{data[:player_height]}"
                scrolling="no"
                frameborder="0">
        </iframe>
        RAW
      end

      def article_html
        layout.to_html
      end

      def image_html
        return if Onebox::Helpers.blank?(data[:image])

        escaped_src = ::Onebox::Helpers.normalize_url_for_output(data[:image])

        alt    = data[:description]  || data[:title]
        width  = data[:image_width]  || data[:thumbnail_width]  || data[:width]
        height = data[:image_height] || data[:thumbnail_height] || data[:height]

        "<img src='#{escaped_src}' alt='#{alt}' width='#{width}' height='#{height}' class='onebox'>"
      end

      def video_html
        escaped_video_src = ::Onebox::Helpers.normalize_url_for_output(data[:video])
        escaped_image_src = ::Onebox::Helpers.normalize_url_for_output(data[:image])

        <<-HTML
          <video
            title='#{data[:title]}'
            width='#{data[:video_width]}'
            height='#{data[:video_height]}'
            style='max-width:100%'
            poster='#{escaped_image_src}'
            controls=''
          >
            <source src='#{escaped_video_src}'>
          </video>
        HTML
      end

      def embedded_html
        fragment = Nokogiri::HTML5::fragment(data[:html])
        fragment.css("img").each { |img| img["class"] = "thumbnail" }
        if iframe = fragment.at_css("iframe")
          iframe.remove_attribute("style")
          iframe["width"] = data[:width] || "100%"
          iframe["height"] = data[:height]
          iframe["scrolling"] = "no"
          iframe["frameborder"] = "0"
        end
        fragment.to_html
      end
    end
  end
end
