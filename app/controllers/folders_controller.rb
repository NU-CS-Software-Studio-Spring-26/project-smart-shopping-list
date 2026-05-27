class FoldersController < ApplicationController
  before_action :set_folder, only: [ :show, :edit, :update, :destroy ]

  def index
    @folders = Current.user.folders.order(:name)
  end

  def show
    @products_in_folder = @folder.products.order(:name)
    @products_not_in_folder = Current.user.products
                                          .where.not(id: @products_in_folder.select(:id))
                                          .order(:name)
  end

  def new
    @folder = Current.user.folders.build
  end

  def create
    @folder = Current.user.folders.build(folder_params)
    if @folder.save
      redirect_to @folder, notice: "Folder created!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @folder.update(folder_params)
      redirect_to @folder, notice: "Folder updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @folder.destroy
    redirect_to folders_url, notice: "Folder deleted."
  end

  private

  def set_folder
    @folder = Current.user.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :description)
  end
end
