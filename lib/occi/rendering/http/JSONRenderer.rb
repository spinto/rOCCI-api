##############################################################################
#  Copyright 2011 Service Computing group, TU Dortmund
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
##############################################################################

##############################################################################
# Description: OCCI HTTP Rendering
# Author(s): Hayati Bice, Florian Feldhaus, Piotr Kasprzak
##############################################################################

require 'json'
require 'occi/core/Action'
require 'occi/core/Kind'
require 'occi/core/Mixin'

require 'occi/rendering/http/LocationRegistry'
require 'occi/rendering/AbstractRenderer'

module OCCI
  module Rendering
    module HTTP

      class JSONRenderer < OCCI::Rendering::AbstractRenderer

        # ---------------------------------------------------------------------------------------------------------------------
        private
        # ---------------------------------------------------------------------------------------------------------------------

        # ---------------------------------------------------------------------------------------------------------------------
        def is_numeric?(object)
          true if Float(object) rescue false
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def attribute_to_hash(attribute)
          
          hash = {}
          hash['mutable']   = attribute.mutable
          hash['required']  = attribute.required
          hash['type']      = attribute.type
          hash['range']     = attribute.range
          hash['default']   = attribute.default

          return hash
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def attributes_to_hash(attributes)
          
          hash = {}
          attributes.each do |key, value|
            hash[key] = value.to_hash
          end
          return hash
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def category_to_hash(category)                  

          hash = {}
          hash['term']       = category.term
          hash['scheme']     = category.scheme
          hash['title']      = category.title
          hash['attributes'] = category.attributes.to_hash unless category.attributes.to_hash.empty?
          hash['location']   = category.location
          
          return hash
        end

        # ---------------------------------------------------------------------------------------------------------------------        
        public
        # ---------------------------------------------------------------------------------------------------------------------

        # ---------------------------------------------------------------------------------------------------------------------
        def prepare_renderer()
          # Re-initialize header array
          @data = {}
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def render_category_type(categories)

          categories.each do |category|
            if category.instance_of?(OCCI::Core::Category)
              @data[:categories] = [category_to_hash(category)] + @data[:categories].to_a
              next
            end

            if category.kind_of?(OCCI::Core::Mixin)
              @data[:mixins] = [category_to_hash(category)] + @data[:categories].to_a
              next
            end

            if category.kind_of?(OCCI::Core::Kind)
              @data[:kinds] = [category_to_hash(category)] + @data[:categories].to_a
              next
            end
          end
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def render_category_short(category)
          hash = {}
          hash['term']       = category.term
          hash['scheme']     = category.scheme
          return hash
        end

        # ---------------------------------------------------------------------------------------------------------------------
        # render single location if a new resource has been created (e.g. use Location instead of X-OCCI-Location)
        def render_location(location)
          @data.merge!({ "Location" => location })
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def render_link_reference(link)
          hash = {}
          hash['title'] = link.attributes['occi.core.title']
          hash['target'] = link.attributes['occi.core.target']
          target_object = OCCI::Rendering::HTTP::LocationRegistry.get_object_by_location(link.attributes['occi.core.target'])
          hash['target_type'] = target_object.type_identifier
          hash['location'] = link.get_location
          hash['type'] = link.type_identifier
          hash['attributes'] = render_attributes(link.attributes)
          return hash
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def render_action_reference(action, resource)
          hash = {}
          hash['title'] = action.category.title
          hash['uri'] = OCCI::Rendering::HTTP::LocationRegistry.get_location_of_object(resource) + '?action=' + action.category.term
          hash['type'] = action.category.type_identifier
          return hash
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def render_attributes(attributes)
          return attributes
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def render_locations(locations)
          # JSON does not render locations anymore. text/uri-list should be used to get locations
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def render_entity(entity)

          entity_rendering = {}
          # render kind of entity
          entity_rendering.merge!({ :kind => render_category_short(entity.kind)  } )

          entity_rendering.merge!({:mixins => entity.mixins.collect{|mixin| render_category_short(mixin) } } )

          entity_rendering.merge!({:actions => entity.actions.collect{|action| render_action_reference(action,entity) } } )

          # Render attributes
          entity_rendering.merge!({:attributes => render_attributes(entity.attributes) } )

          entity_rendering.merge!({:links => entity.links.collect{|link| render_link_reference(link) } } ) if entity.kind_of?(OCCI::Core::Resource)

          entity_rendering.merge!({:location => entity.get_location } )

          @data['collection'] = [entity_rendering]  + @data['collection'].to_a
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def data()
          return @data
        end

        # ---------------------------------------------------------------------------------------------------------------------
        def render_response(response)

          # Don't put any data in the response if there was an error
          return if response.status != OCCI::Rendering::HTTP::HTTP_OK

          response.write(JSON.pretty_generate(@data))
        end        
  
      end
      
    end
  end
end