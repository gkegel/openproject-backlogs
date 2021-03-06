
require File.dirname(__FILE__) + '/../../spec_helper'

describe 'rb_master_backlogs/index' do
  let(:user) { FactoryGirl.create(:user) }
  let(:role_allowed) { FactoryGirl.create(:role,
    :permissions => [:view_master_backlog, :view_taskboards])
  }
  let(:statuses) { [FactoryGirl.create(:status, is_default: true),
                    FactoryGirl.create(:status),
                    FactoryGirl.create(:status)] }
  let(:type_task) { FactoryGirl.create(:type_task) }
  let(:type_feature) { FactoryGirl.create(:type_feature) }
  let(:issue_priority) { FactoryGirl.create(:priority) }
  let(:project) do
    project = FactoryGirl.create(:project, :types => [type_feature, type_task])
    project.members = [FactoryGirl.create(:member, :principal => user,:project => project,:roles => [role_allowed])]
    project
  end
  let(:story_a) { FactoryGirl.create(:story, :status => statuses[0],
                                             :project => project,
                                             :type => type_feature,
                                             :fixed_version => sprint,
                                             :priority => issue_priority
                                             )}
  let(:story_b) { FactoryGirl.create(:story, :status => statuses[1],
                                             :project => project,
                                             :type => type_feature,
                                             :fixed_version => sprint,
                                             :priority => issue_priority
                                             )}
  let(:story_c) { FactoryGirl.create(:story, :status => statuses[2],
                                             :project => project,
                                             :type => type_feature,
                                             :fixed_version => sprint,
                                             :priority => issue_priority
                                             )}
  let(:stories) { [story_a, story_b, story_c] }
  let(:sprint)   { FactoryGirl.create(:sprint, :project => project) }

  before :each do
    Setting.stub(:plugin_openproject_backlogs).and_return({"story_types" => [type_feature.id], "task_type" => type_task.id})
    view.extend RbCommonHelper
    view.extend RbMasterBacklogsHelper
    view.stub(:current_user).and_return(user)

    assign(:project, project)
    assign(:sprint, sprint)
    assign(:owner_backlogs, Backlog.owner_backlogs(project))
    assign(:sprint_backlogs, Backlog.sprint_backlogs(project))

    User.stub(:current).and_return(user)

    # We directly force the creation of stories by calling the method
    stories
  end

  it 'shows link to export with the default export card configuration' do
    default_export_card_config = FactoryGirl.create(:export_card_configuration)
    assign(:export_card_config_meta, {
      default: default_export_card_config,
      count: 1})

    render

    assert_select ".menu ul.items a" do |a|
      url = backlogs_project_sprint_export_card_configuration_path(project.identifier, sprint.id, default_export_card_config.id, format: :pdf)
      a.last.should have_content 'Export'
      a.last.should have_css("a[href='#{url}']")
    end
  end

  it 'shows link to display export card configuration choice modal' do
    assign(:export_card_config_meta, { count: 2 })
    render

    assert_select ".menu ul.items a" do |a|
      url = backlogs_project_sprint_export_card_configurations_path(project.id, sprint.id)
      a.last.should have_content 'Export'
      a.last.should have_css("a[href='#{url}']")
      a.last.should have_css("a[data-modal]")
    end
  end
end