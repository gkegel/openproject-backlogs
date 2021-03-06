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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe WorkPackage do
  describe 'Story positions' do
    def build_work_package(options)
      FactoryGirl.build(:work_package, options.reverse_merge(:fixed_version_id => sprint_1.id,
                                                  :priority_id      => priority.id,
                                                  :project_id       => project.id,
                                                  :status_id        => status.id,
                                                  :type_id       => story_type.id))
    end

    def create_work_package(options)
      build_work_package(options).tap { |i| i.save! }
    end

    let(:status)   { FactoryGirl.create(:status)    }
    let(:priority) { FactoryGirl.create(:priority_normal) }
    let(:project)  { FactoryGirl.create(:project)         }

    let(:story_type) { FactoryGirl.create(:type, :name => 'Story')    }
    let(:epic_type)  { FactoryGirl.create(:type, :name => 'Epic')     }
    let(:task_type)  { FactoryGirl.create(:type, :name => 'Task')     }
    let(:other_type) { FactoryGirl.create(:type, :name => 'Feedback') }

    let(:sprint_1) { FactoryGirl.create(:version, :project_id => project.id, :name => 'Sprint 1') }
    let(:sprint_2) { FactoryGirl.create(:version, :project_id => project.id, :name => 'Sprint 2') }

    let(:work_package_1) { create_work_package(:subject => 'WorkPackage 1', :fixed_version_id => sprint_1.id) }
    let(:work_package_2) { create_work_package(:subject => 'WorkPackage 2', :fixed_version_id => sprint_1.id) }
    let(:work_package_3) { create_work_package(:subject => 'WorkPackage 3', :fixed_version_id => sprint_1.id) }
    let(:work_package_4) { create_work_package(:subject => 'WorkPackage 4', :fixed_version_id => sprint_1.id) }
    let(:work_package_5) { create_work_package(:subject => 'WorkPackage 5', :fixed_version_id => sprint_1.id) }

    let(:work_package_a) { create_work_package(:subject => 'WorkPackage a', :fixed_version_id => sprint_2.id) }
    let(:work_package_b) { create_work_package(:subject => 'WorkPackage b', :fixed_version_id => sprint_2.id) }
    let(:work_package_c) { create_work_package(:subject => 'WorkPackage c', :fixed_version_id => sprint_2.id) }

    let(:feedback_1)  { create_work_package(:subject => 'Feedback 1', :fixed_version_id => sprint_1.id,
                                                               :type_id => other_type.id) }

    let(:task_1)  { create_work_package(:subject => 'Task 1', :fixed_version_id => sprint_1.id,
                                                       :type_id => task_type.id) }

    before do
      # We had problems while writing these specs, that some elements kept
      # creaping around between tests. This should be fast enough to not harm
      # anybody while adding an additional safety net to make sure, that
      # everything runs in isolation.
      WorkPackage.delete_all
      IssuePriority.delete_all
      Status.delete_all
      Project.delete_all
      Type.delete_all
      Version.delete_all

      # Enable and configure backlogs
      project.enabled_module_names = project.enabled_module_names + ["backlogs"]
      Setting.stub(:plugin_openproject_backlogs).and_return({"story_types" => [story_type.id, epic_type.id], "task_type"   => task_type.id})

      # Otherwise the type id's from the previous test are still active
      WorkPackage.instance_variable_set(:@backlogs_types, nil)

      project.types = [story_type, epic_type, task_type, other_type]
      sprint_1
      sprint_2

      # Create and order work_packages
      work_package_1.move_to_bottom
      work_package_2.move_to_bottom
      work_package_3.move_to_bottom
      work_package_4.move_to_bottom
      work_package_5.move_to_bottom

      work_package_a.move_to_bottom
      work_package_b.move_to_bottom
      work_package_c.move_to_bottom
    end

    describe '- Creating a work_package in a sprint' do
      it 'adds it to the bottom of the list' do
        new_work_package = create_work_package(:subject => 'Newest WorkPackage', :fixed_version_id => sprint_1.id)

        new_work_package.should_not be_new_record
        new_work_package.should be_last
      end

      it 'does not reorder the existing work_packages' do
        new_work_package = create_work_package(:subject => 'Newest WorkPackage', :fixed_version_id => sprint_1.id)

        [work_package_1, work_package_2, work_package_3, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4, 5]
      end
    end

    describe '- Removing a work_package from the sprint' do
      it 'reorders the remaining work_packages' do
        work_package_2.fixed_version = sprint_2
        work_package_2.save!

        sprint_1.fixed_issues.all(:order => 'id').should == [work_package_1, work_package_3, work_package_4, work_package_5]
        sprint_1.fixed_issues.all(:order => 'id').each(&:reload).map(&:position).should == [1, 2, 3, 4]
      end
    end

    describe '- Adding a work_package to a sprint' do
      it 'adds it to the bottom of the list' do
        work_package_a.fixed_version = sprint_1
        work_package_a.save!

        work_package_a.should be_last
      end

      it 'does not reorder the existing work_packages' do
        work_package_a.fixed_version = sprint_1
        work_package_a.save!

        [work_package_1, work_package_2, work_package_3, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4, 5]
      end
    end

    describe '- Deleting a work_package in a sprint' do
      it 'reorders the existing work_packages' do
        work_package_3.destroy

        [work_package_1, work_package_2, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4]
      end
    end

    describe '- Changing the type' do
      describe 'by moving a story to another story type' do
        it 'keeps all positions in the sprint in tact' do
          work_package_3.type = epic_type
          work_package_3.save!

          [work_package_1, work_package_2, work_package_3, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4, 5]
        end
      end

      describe 'by moving a story to a non-backlogs type' do
        it 'removes it from any list' do
          work_package_3.type = other_type
          work_package_3.save!

          work_package_3.should_not be_in_list
        end

        it 'reorders the remaining stories' do
          work_package_3.type = other_type
          work_package_3.save!

          [work_package_1, work_package_2, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4]
        end
      end

      describe 'by moving a story to the task type' do
        it 'removes it from any list' do
          work_package_3.type = task_type
          work_package_3.save!

          work_package_3.should_not be_in_list
        end

        it 'reorders the remaining stories' do
          work_package_3.type = task_type
          work_package_3.save!

          [work_package_1, work_package_2, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4]
        end
      end

      describe 'by moving a task to the story type' do
        it 'adds it to the bottom of the list' do
          task_1.type = story_type
          task_1.save!

          task_1.should be_last
        end

        it 'does not reorder the existing stories' do
          task_1.type = story_type
          task_1.save!

          [work_package_1, work_package_2, work_package_3, work_package_4, work_package_5, task_1].each(&:reload).map(&:position).should == [1, 2, 3, 4, 5, 6]
        end
      end

      describe 'by moving a non-backlogs work_package to a story type' do
        it 'adds it to the bottom of the list' do
          feedback_1.type = story_type
          feedback_1.save!

          feedback_1.should be_last
        end

        it 'does not reorder the existing stories' do
          feedback_1.type = story_type
          feedback_1.save!

          [work_package_1, work_package_2, work_package_3, work_package_4, work_package_5, feedback_1].each(&:reload).map(&:position).should == [1, 2, 3, 4, 5, 6]
        end
      end
    end

    describe '- Moving work_packages between projects' do
      # N.B.: You cannot move a ticket to another project and change the
      # 'fixed_version' at the same time. On the other hand, OpenProject tries
      # to keep the 'fixed_version' if possible (e.g. within project
      # hierarchies with shared versions)

      let(:project_wo_backlogs) { FactoryGirl.create(:project) }
      let(:sub_project_wo_backlogs) { FactoryGirl.create(:project) }

      let(:shared_sprint)   { FactoryGirl.create(:version,
                                             :project_id => project.id,
                                             :name => 'Shared Sprint',
                                             :sharing => 'descendants') }

      let(:version_go_live) { FactoryGirl.create(:version,
                                             :project_id => project_wo_backlogs.id,
                                             :name => 'Go-Live') }

      before do
        project_wo_backlogs.enabled_module_names = project_wo_backlogs.enabled_module_names - ["backlogs"]
        sub_project_wo_backlogs.enabled_module_names = sub_project_wo_backlogs.enabled_module_names - ["backlogs"]

        project_wo_backlogs.types = [story_type, task_type, other_type]
        sub_project_wo_backlogs.types = [story_type, task_type, other_type]

        sub_project_wo_backlogs.move_to_child_of(project)

        shared_sprint
        version_go_live
      end

      describe '- Moving an work_package from a project without backlogs to a backlogs_enabled project' do
        describe 'if the fixed_version may not be kept' do
          let(:work_package_i) { create_work_package(:subject => 'WorkPackage I',
                                       :fixed_version_id => version_go_live.id,
                                       :project_id => project_wo_backlogs.id) }
          before do
            work_package_i
          end

          it 'sets the fixed_version_id to nil' do
            result = work_package_i.move_to_project(project)

            result.should be_true

            work_package_i.fixed_version.should be_nil
          end

          it 'removes it from any list' do
            result = work_package_i.move_to_project(project)

            result.should be_true

            work_package_i.should_not be_in_list
          end
        end

        describe 'if the fixed_version may be kept' do
          let(:work_package_i) { create_work_package(:subject => 'WorkPackage I',
                                       :fixed_version_id => shared_sprint.id,
                                       :project_id => sub_project_wo_backlogs.id) }

          before do
            work_package_i
          end

          it 'keeps the fixed_version_id' do
            result = work_package_i.move_to_project(project)

            result.should be_true

            work_package_i.fixed_version.should == shared_sprint
          end

          it 'adds it to the bottom of the list' do
            result = work_package_i.move_to_project(project)

            result.should be_true

            work_package_i.should be_first
          end
        end
      end

      describe '- Moving an work_package away from backlogs_enabled project to a project without backlogs' do
        describe 'if the fixed_version may not be kept' do
          it 'sets the fixed_version_id to nil' do
            result = work_package_3.move_to_project(project_wo_backlogs)

            result.should be_true

            work_package_3.fixed_version.should be_nil
          end

          it 'removes it from any list' do
            result = work_package_3.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            work_package_3.should_not be_in_list
          end

          it 'reorders the remaining work_packages' do
            result = work_package_3.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            [work_package_1, work_package_2, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4]
          end
        end

        describe 'if the fixed_version may be kept' do
          let(:work_package_i)   { create_work_package(:subject => 'WorkPackage I',
                                         :fixed_version_id => shared_sprint.id) }
          let(:work_package_ii)  { create_work_package(:subject => 'WorkPackage II',
                                         :fixed_version_id => shared_sprint.id) }
          let(:work_package_iii) { create_work_package(:subject => 'WorkPackage III',
                                         :fixed_version_id => shared_sprint.id) }

          before do
            work_package_i.move_to_bottom
            work_package_ii.move_to_bottom
            work_package_iii.move_to_bottom

            [work_package_i, work_package_ii, work_package_iii].map(&:position).should == [1, 2, 3]
          end

          it 'keeps the fixed_version_id' do
            result = work_package_ii.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            work_package_ii.fixed_version.should == shared_sprint
          end

          it 'removes it from any list' do
            result = work_package_ii.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            work_package_ii.should_not be_in_list
          end

          it 'reorders the remaining work_packages' do
            result = work_package_ii.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            [work_package_i, work_package_iii].each(&:reload).map(&:position).should == [1, 2]
          end
        end
      end
    end
  end
end
