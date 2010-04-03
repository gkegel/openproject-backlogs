include StoriesHelper

class BacklogsController < ApplicationController
  unloadable

  before_filter :find_project, :authorize

  def index
    @settings = Setting.plugin_redmine_backlogs
    @product_backlog_stories = Story.product_backlog(@project)
    @sprints = Sprint.open_sprints(@project)
    
    if @settings[:story_trackers].nil? || @settings[:task_tracker].nil?
      render :action => "noconfig", :layout => "backlogs"
    else
      render :action => "index", :layout => "backlogs"
    end
  end
  
  def jsvariables
    render :action => "jsvariables.js", :content_type => 'text/javascript', :layout => false
  end

  def reorder
    dropped = params[:dropped]

    pred = nil
    found = false
    if !params[:story].nil?
        params[:story].each { |id|
            if id == dropped
                found = true
                break
            end
            pred = id
        }
    end

    if found
        story = Story.find(dropped)

        if params[:moveto]
            if params[:moveto] == 'product_backlog'
                story.update_attribute(:fixed_version_id, nil)
            else
                sprint = params[:moveto]
                sprint = Sprint.first(:conditions => { :project_id => @project.id, :id => sprint})
                story.update_attribute(:fixed_version_id, sprint.id)
            end
        end

        if pred.nil?
            story.move_to_top
        else
            pred = Story.find(pred)
            story.insert_at(pred.position + 1)
        end
    end

    render :nothing => true, :status => 200
  end

  def rename
    type, name, id = (params[:id].split('-'))
    value = params[:value]

    if type == 'sprint'
        sprint = Sprint.first(:conditions => { :project_id => @project.id, :id => id})
        sprint.update_attribute(:name, value)
    elsif type == 'story'
        story = Story.first(:conditions => { :project_id => @project.id, :id => id})
        story.update_attribute(:subject, value)
    else
        render :nothing => true, :status => 500
    end

    render :text => value, :status => 200
  end

  def sprint_date
    date = params[:date]
    sprint = params[:sprint]
    type = params[:type]

    sprint = Sprint.first(:conditions => { :project_id => @project.id, :id => sprint})

    if type == 'start'
        sprint.update_attribute(:start_date, date)
    elsif type == 'end'
        sprint.update_attribute(:effective_date, date)
    else
        render :nothing => true, :status => 500
    end

    render :text => date, :status => 200
  end

  def story_points
    points, sprint, story, id = params[:id].split('-')
    story = Story.first(:conditions => { :project_id => @project.id, :id => id})

    begin
        story.set_points(params[:value])
    rescue
        # ignore non-integer values
    end

    render :text => story.points_display, :status => 200
  end

  def select_sprint
    @query = Query.new(:name => "_")
    @query.project = @project

    @query.add_filter("status_id", '*', ['']) # All statuses
    @query.add_filter("fixed_version_id", '=', [params[:sprint_id]])

    session[:query] = {:project_id => @query.project_id, :filters => @query.filters}

    redirect_to :controller => 'issues', :action => 'index', :project_id => @project.id
  end

  def wiki_page
    sprint = Sprint.first(:conditions => { :project_id => @project.id, :id => params[:sprint_id]})
    redirect_to :controller => 'wiki', :action => 'index', :id => @project.id, :page => sprint.wiki_page
  end

  def wiki_page_edit
    sprint = Sprint.first(:conditions => { :project_id => @project.id, :id => params[:sprint_id]})
    redirect_to :controller => 'wiki', :action => 'edit', :id => @project.id, :page => sprint.wiki_page
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end
end