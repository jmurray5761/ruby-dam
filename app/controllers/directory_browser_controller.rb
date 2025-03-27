class DirectoryBrowserController < ApplicationController
  SUPPORTED_FORMATS = %w[.jpg .jpeg .png .gif].freeze

  def index
    @current_path = params[:path] || Rails.root.to_s
    @files = list_directory(@current_path)
    @parent_path = File.dirname(@current_path)
    
    respond_to do |format|
      format.html
      format.json { render json: { files: @files, current_path: @current_path, parent_path: @parent_path } }
    end
  end

  private

  def list_directory(path)
    return [] unless File.directory?(path)
    
    Dir.entries(path)
       .reject { |f| f.start_with?('.') }
       .map do |f|
         full_path = File.join(path, f)
         {
           name: f,
           path: full_path,
           type: File.directory?(full_path) ? 'directory' : 'file',
           size: File.size(full_path),
           modified: File.mtime(full_path),
           is_image: SUPPORTED_FORMATS.include?(File.extname(f).downcase)
         }
       end
       .sort_by { |f| [f[:type] == 'directory' ? 0 : 1, f[:name].downcase] }
  rescue StandardError => e
    Rails.logger.error("Error listing directory: #{e.message}")
    []
  end
end 