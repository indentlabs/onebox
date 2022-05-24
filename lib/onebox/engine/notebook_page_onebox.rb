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
        display_path = extract_path(og.url, max_length)

        {
          link: url,
          image: og.image,
          path: path,
          title: Onebox::Helpers.truncate(og.titletitle, 250),
          description: Onebox::Helpers.truncate(og.description, 400),
          favicon: get_favicon
        }
      end

      def extract_path(root, max_length)
        path = url.split('#')[0].split('?')[0]
        path = path["#{root}/tree/".length..-1]

        return unless path

        path.length > max_length ? path[-max_length..-1] : path
        end
    end
  end
end
