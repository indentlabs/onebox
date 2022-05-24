# frozen_string_literal: true

module Onebox
  module Engine
    class NotebookPageOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(/^https?:\/\/(?:www\.)?(?:(?:\w)+\.)?notebook\.ai\/plan\/*([^\/]+)\/(\d+)/)
      always_https

      private

      def data
        og = get_opengraph

        {
          link: url,
          image: og.image,
          title: Onebox::Helpers.truncate(og.titletitle, 250),
          description: Onebox::Helpers.truncate(og.description, 400),
          favicon: get_favicon
        }
      end
    end
  end
end
