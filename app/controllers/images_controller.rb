class ImagesController < ApplicationController
  include Pagy::Backend

  def index
    @pagy, @images = pagy(Image.order(created_at: :desc), items: 20)
  end

  def show
    @image = Image.find(params[:id])
  end

  def new
    @image = Image.new
  end

  def create
    @image = Image.new(image_params)

    if params[:image][:generate_name_and_description] == '1'
      # Allow name and description to be blank
      @image.name = nil
      @image.description = nil

      if @image.save
        @image.generate_name_and_description
        @image.save # Save again to persist the generated name and description
        redirect_to @image, notice: 'Image was successfully uploaded and processed.'
      else
        render :new, status: :unprocessable_entity
      end
    else
      if @image.save
        redirect_to @image, notice: 'Image was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
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
      render :edit, status: :unprocessable_entity
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

    redirect_to root_path, status: :see_other
  end


  private

  def image_params
    params.require(:image).permit(:name, :description, :file, :generate_name_and_description)
  end
end
