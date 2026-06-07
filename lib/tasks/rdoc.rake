namespace :rdoc do
  desc "Generate RDoc API documentation into doc/"
  task generate: :environment do
    require "rdoc/task"

    RDoc::Task.new(:app) do |rdoc|
      rdoc.rdoc_dir = "doc"
      rdoc.title    = "PriceTracker API Documentation"
      rdoc.main     = "README.md"
      rdoc.rdoc_files.include("README.md", "app/**/*.rb", "lib/**/*.rb")
      rdoc.options << "--line-numbers"
    end

    Rake::Task[:app].invoke
    puts "RDoc generated in doc/"
  end
end
