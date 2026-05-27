class FoldersController < ApplicationController
  before_action :set_folder, only: [ :show, :edit, :update, :destroy ]

  def index
    @folders = Current.user.folders.order(:name).includes(:products)
  end

  def show
    scope = @folder.products
    scope = fuzzy_search(scope, params[:search]) if params[:search].present?
    scope = scope.where(category: params[:category]) if params[:category].present?
    scope = scope.where("? = ANY(tags)", params[:tag].to_s.downcase) if params[:tag].present?
    scope = sort_products(scope, params[:sort])

    count_scope = @folder.products
    count_scope = fuzzy_search(count_scope, params[:search]) if params[:search].present?
    count_scope = count_scope.where(category: params[:category]) if params[:category].present?
    count_scope = count_scope.where("? = ANY(tags)", params[:tag].to_s.downcase) if params[:tag].present?

    @pagy, @products_in_folder = pagy(scope, count: count_scope.count, limit: 24)
    @products_in_folder.load

    @categories = @folder.products.distinct.pluck(:category).compact.sort
    @tags = @folder.products.pluck(:tags).flatten.uniq.sort
    @products_not_in_folder = Current.user.products
                                          .where.not(id: @folder.products.select(:id))
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
