require 'yaml'
require 'pp'
require 'fileutils'
require 'pathname'

class DECALConf
  @@parameters = ["num_x",  "num_y",  "slab_ratio",  "max_init",  "min_init",
                      "num_iterations",  "print_interval",  "continue_from",  "boundary_type",
                      "starting_morph",  "pe",  "pd_one",  "pd_none",  "jump_length",  "num_sprinkled",
                      "band_width",  "band_lower",  "band_upper"]
                      
  @@param_comments = ["int____number_of_x_cells",
                                   "int____number_of_y_cells", "double_slab_ratio",
                                   "int____upper_limit_of_number_of_allowable_slabs_initially",
                                   "int____lower_limit_of_number_of_allowable_slabs_initially",
                                   "int____number_of_iterations",
                                   "int____number_of_iterations_between_printing_of_plots_must_be_a_factor_of_itno",
                                   "int____print_cycle_continue_from",
                                   "int____type_of_boundary_____0_periodic_____5_non_periodic",
                                   "int____starting_morphology__0_random__1_flat_2_predefined",
                                   "double_probability_of_erosion",
                                   "double_probability_of_deposition_on_cell_with_at_least_one_slab",
                                   "double_probability_of_deposition_on_cell_with_no_slabs",
                                   "int____jump_length_can_be_negative",
                                   "int____no_of_slabs_sprinkled_per_it",
                                   "int____width_of_band",
                                   "int____lower_coord_of_band",
                                   "int____upper_coord_of_band"]

  @@parameters.each do |param|
    attr(param, true)
  end
  
  attr_accessor :name
  
  def load_from_yaml(name, obj)
    @name = name
    
    set_values(obj, @@parameters)
  end
  
  def self.create_from_object(object)
    return object.clone
  end
  
  def to_s
    @num_x.to_s + " , " + @num_y.to_s + " , " + @num_iterations.to_s + " , " + @pe.to_s
  end
  
  def write_to_file(output_file)
    File.open(output_file, 'w') do |f|
      f.puts "DECAL_input_parameters\n"
      f.puts "\n"
      
      if @boundary_type == "periodic" then @boundary_type = 0 elsif @boundary_type == "non-periodic" then @boundary_type = 5 end
      
      @starting_morph = case @starting_morph
        when "random" then 0
        when "flat" then 1
        when "predefined" then 2
        end
      
      @@parameters.each_with_index do |param, index|
        var = instance_variable_get("@#{param}")
        f.puts var.to_s + " (" + @@param_comments[index] + ")\n"
        end
      end
  end
  
  private
  
  def set_values(h, keys)
    keys.each do |key|
      instance_variable_set "@#{key}", h[key] unless h[key].nil?
    end
  end

end

if ARGV.length == 0 then
  puts "DECWork - The DECAL-running Framework"
  puts "--------------------------------------------------"
  puts "Usage Instructions:"
  puts "To create scenarios: decwork create filename.yml /path/to/folder/base /path/to/decal_erosion"
  puts "To post-process scenarios: decwork post-process"
  puts "Written by Robin Wilson (robin@rtwilson.com)"
elsif ARGV[0] == "create" then
  filename = ARGV[1]
  folder_base = ARGV[2]
  base_path = Pathname.new(folder_base)
  
  decal_exe_path = ARGV[3]
  
  puts "Starting to process #{filename}"

  # Make the root directory
  FileUtils.mkdir(folder_base)

  # Load the given YAML file
  file_data = YAML.load_file(filename)

  # Load the _base element
  base_conf = DECALConf.new
  base_conf.load_from_yaml("_base", file_data['_base'])

  # Remove the _base element so it isn't included in the scenarios
  file_data.delete('_base')

  # Initialise scenarios array
  scenarios = []

  #
  file_data.each do |key, value|
    puts "Processing scenario: #{key}"
    temp = DECALConf.create_from_object(base_conf)
    temp.load_from_yaml(key, value)
    scenarios.push(temp)
    end

  batch_file = File.join(folder_base, "run_decal.sh")

  File.open(batch_file, 'w') do |f|
    # Initialise the scenario number
    scen_num = 1

    scenarios.each do |scen|
      # Create the folder for this scenario
      folder_name = "S#{scen_num.to_s}_#{scen.name}"
      folder_path = File.join(folder_base, folder_name)
      FileUtils.mkdir(folder_path)
      
      # Write the configuration file to the folder
      scen.write_to_file(File.join(folder_path, "DECALinputdata.txt"))
      
      # Copy the DECAL exe to this new directory
      FileUtils.cp(decal_exe_path, File.join(folder_path, "decal_erosion"))
      
      path_folder = Pathname.new(folder_path)
      
      batch_line = File.join(path_folder.relative_path_from(base_path), "decal_erosion")
      f.puts batch_line
      
      # Update scenario number
      scen_num = scen_num + 1
      end
    end
elsif ARGV[0] == "post-process" then
  base_dir = ARGV[1]
  
  # Change to the base directory given
  Dir.chdir(base_dir)
  
  # Get a list of all the files - including within subdirectories
  filenames = Dir.glob("**/**/**/sand*.txt")
  
  filenames.each do |filename|
    full_filename = File.expand_path(filename)
    puts "Processing #{full_filename}"
    path = Pathname.new(full_filename)
    new_filename = "#{File.join(path.dirname, path.dirname.basename)}_#{path.basename}"
    FileUtils.mv(filename, new_filename)
  end
end