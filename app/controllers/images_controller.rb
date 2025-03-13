class ImagesController < ApplicationController
  include Pagy::Backend

  def index
    @pagy, @images = pagy(Image.includes(file_attachment: { blob: :variant_records }).order(created_at: :desc), items: 20)
  end

  def show
    @image = Image.find(params[:id])
  end

  def new
    @image = Image.new
  end

  def create
    Rails.logger.info("Starting image creation")
    Rails.logger.info("Params: #{params.inspect}")
    
    @image = Image.new(image_params)
    @image.generate_name_and_description = params[:image][:generate_name_and_description] == '1'
    
    Rails.logger.info("Image attributes: #{@image.attributes}")
    Rails.logger.info("File attached?: #{@image.file.attached?}")
    Rails.logger.info("Generate name and description: #{@image.generate_name_and_description}")

    begin
      if @image.save
        Rails.logger.info("Image saved successfully")
        redirect_to @image, notice: 'Image was successfully uploaded and processed.'
      else
        Rails.logger.error("Failed to save image: #{@image.errors.full_messages}")
        render :new, status: :unprocessable_entity
      end
    rescue ActiveStorage::FileNotFoundError => e
      Rails.logger.error("File upload error: #{e.message}")
      @image.errors.add(:file, "File upload failed. Please try again.")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @image = Image.find(params[:id])
  end

  def update
    @image = Image.find(params[:id])
    if @image.update(image_params)
      redirect_to @image
    else
      render :edit
    end
  end

  def destroy
    @image = Image.find_by(id: params[:id])
    if @image
      # Destroys the image along with any associated attachments.
      @image.destroy
      if @image.destroyed?
        flash[:notice] = "Image and associated files deleted successfully."
      else
        flash[:error] = "Failed to delete the image."
      end
    else
      flash[:alert] = "Image not found."
    end

    redirect_to images_url, status: :see_other
  end

  private

  def image_params
    params.require(:image).permit(:name, :description, :file)
  end
end
