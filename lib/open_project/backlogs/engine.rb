#-- copyright
# OpenProject Backlogs Plugin
#
# Copyright (C)2013 the OpenProject Foundation (OPF)
# Copyright (C)2011 Stephan Eckardt, Tim Felgentreff, Marnen Laibow-Koser, Sandro Munda
# Copyright (C)2010-2011 friflaj
# Copyright (C)2010 Maxime Guilbot, Andrew Vit, Joakim Kolsjö, ibussieres, Daniel Passos, Jason Vasquez, jpic, Emiliano Heyns
# Copyright (C)2009-2010 Mark Maglana
# Copyright (C)2009 Joe Heck, Nate Lowrie
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 3.
#
# OpenProject Backlogs is a derivative work based on ChiliProject Backlogs.
# The copyright follows:
# Copyright (C) 2010-2011 - Emiliano Heyns, Mark Maglana, friflaj
# Copyright (C) 2011 - Jens Ulferts, Gregor Schmidt - Finn GmbH - Berlin, Germany
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require 'acts_as_silent_list'

module OpenProject::Backlogs
  class Engine < ::Rails::Engine
    engine_name :openproject_backlogs

    def self.settings
      { :default => { "story_types"  => nil,
                      "task_type"    => nil,
                      "card_spec"       => nil
      },
      :partial => 'shared/settings' }
    end

    config.autoload_paths += Dir["#{config.root}/lib/"]

    initializer 'backlogs.precompile_assets' do
      Rails.application.config.assets.precompile += %w( backlogs.css backlogs.js master_backlogs.css taskboard.css)
    end

    config.before_configuration do |app|
      # This is required for the routes to be loaded first as the routes should
      # be prepended so they take precedence over the core.
      app.config.paths['config/routes'].unshift File.join(File.dirname(__FILE__), "..", "..", "..", "config", "routes.rb")
    end

    initializer "remove_duplicate_backlogs_routes", :after => "add_routing_paths" do |app|
      # Removes duplicate entry from app.routes_reloader. As we prepend the
      # plugin's routes to the load_path up front and rails adds all engines'
      # config/routes.rb later, we have double loaded the routes. This is not
      # harmful as such but leads to duplicate routes which decreases
      # performance
      app.routes_reloader.paths.uniq!
    end

    initializer 'backlogs.register_test_paths' do |app|
      app.config.plugins_to_test_paths << self.root
    end

    # Adds our factories to factory girl's load path
    initializer "backlogs.register_factories", :after => "factory_girl.set_factory_paths" do |app|
      FactoryGirl.definition_file_paths << File.expand_path(self.root.to_s + '/spec/factories') if defined?(FactoryGirl)
    end

    initializer 'backlogs.append_migrations' do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    config.to_prepare do

      # TODO: Avoid this dirty hack necessary to prevent settings method getting lost after reloading
      Setting.create_setting("plugin_openproject_backlogs", {'default' => Engine.settings[:default], 'serialized' => true})
      Setting.create_setting_accessors("plugin_openproject_backlogs")

      require_dependency 'work_package'
      require_dependency 'task'
      require_dependency 'acts_as_silent_list'

      if WorkPackage.const_defined? "SAFE_ATTRIBUTES"
        WorkPackage::SAFE_ATTRIBUTES << "story_points"
        WorkPackage::SAFE_ATTRIBUTES << "remaining_hours"
        WorkPackage::SAFE_ATTRIBUTES << "position"
      else
        WorkPackage.safe_attributes "story_points", "remaining_hours", "position"
      end

      # 'require_dependency' reloads the class with every request in development
      # mode which would duplicate the registered view listeners
      require 'open_project/backlogs/hooks'

      require_dependency 'open_project/backlogs/patches'
      require_dependency 'open_project/backlogs/patches/permitted_params_patch'
      require_dependency 'open_project/backlogs/patches/work_package_patch'
      require_dependency 'open_project/backlogs/patches/status_patch'
      require_dependency 'open_project/backlogs/patches/my_controller_patch'
      require_dependency 'open_project/backlogs/patches/project_patch'
      require_dependency 'open_project/backlogs/patches/projects_controller_patch'
      require_dependency 'open_project/backlogs/patches/projects_helper_patch'
      require_dependency 'open_project/backlogs/patches/query_patch'
      require_dependency 'open_project/backlogs/patches/user_patch'
      require_dependency 'open_project/backlogs/patches/version_controller_patch'
      require_dependency 'open_project/backlogs/patches/version_patch'

      unless Redmine::Plugin.registered_plugins.include?(:openproject_backlogs)
        Redmine::Plugin.register :openproject_backlogs do
          name 'OpenProject Backlogs'
          author 'relaxdiego, friflaj, Finn GmbH'
          description 'A plugin for agile teams'

          url 'https://www.openproject.org/projects/plugin-backlogs'
          author_url 'http://www.finn.de/'

          version OpenProject::Backlogs::VERSION

          requires_openproject ">= 3.0.0pre42"

          Redmine::AccessControl.permission(:edit_project).actions << "projects/project_done_statuses"
          Redmine::AccessControl.permission(:edit_project).actions << "projects/rebuild_positions"

          settings Engine.settings

          project_module :backlogs do
            # SYNTAX: permission :name_of_permission, { :controller_name => [:action1, :action2] }

            # Master backlog permissions
            permission :view_master_backlog, {
              :rb_master_backlogs  => :index,
              :rb_sprints          => [:index, :show],
              :rb_wikis            => :show,
              :rb_stories          => [:index, :show],
              :rb_queries          => :show,
              :rb_server_variables => :show,
              :rb_burndown_charts  => :show,
              :rb_export_card_configurations => [:index, :show]
            }

            permission :view_taskboards,     {
              :rb_taskboards       => :show,
              :rb_sprints          => :show,
              :rb_stories          => [:index, :show],
              :rb_tasks            => [:index, :show],
              :rb_impediments      => [:index, :show],
              :rb_wikis            => :show,
              :rb_server_variables => :show,
              :rb_burndown_charts  => :show,
              :rb_export_card_configurations => [:index, :show]
            }

            # Sprint permissions
            # :show_sprints and :list_sprints are implicit in :view_master_backlog permission
            permission :update_sprints,      {
              :rb_sprints => [:edit, :update],
              :rb_wikis   => [:edit, :update]
            }

            # Story permissions
            # :show_stories and :list_stories are implicit in :view_master_backlog permission
            permission :create_stories,         { :rb_stories => :create }
            permission :update_stories,         { :rb_stories => :update }

            # Task permissions
            # :show_tasks and :list_tasks are implicit in :view_sprints
            permission :create_tasks,           { :rb_tasks => [:new, :create]  }
            permission :update_tasks,           { :rb_tasks => [:edit, :update] }

            # Impediment permissions
            # :show_impediments and :list_impediments are implicit in :view_sprints
            permission :create_impediments,     { :rb_impediments => [:new, :create]  }
            permission :update_impediments,     { :rb_impediments => [:edit, :update] }
          end

          menu :project_menu,
            :backlogs,
            {:controller => '/rb_master_backlogs', :action => :index},
            :caption => :project_module_backlogs,
            :before => :calendar,
            :param => :project_id,
            :if => proc { not(User.current.respond_to?(:impaired?) and User.current.impaired?) },
            :html => {:class => 'icon2 icon-backlogs-icon'}

        end
      end

    end
  end
end
