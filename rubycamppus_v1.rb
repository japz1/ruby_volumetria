#!/usr/bin/env ruby

# Modules required:
require 'rubygems'
require 'dcm2nii-ruby'
require 'fsl-ruby'
require 'narray'
require 'nifti'
require 'chunky_png'
require 'optparse'
require 'prawn'
require 'prawn/table'
require 'dicom'
include DICOM

options = {}
option_parser = OptionParser.new do |opts|

  opts.on("-f DICOMDIR", "The DICOM directory") do |dicomdir|
    options[:dicomdir] = dicomdir
  end

  opts.on("-o OUTPUTDIR", "The output directory") do |outputdir|
    options[:outputdir] = outputdir
  end

  opts.on("-d ORIENTATION", "The slices orientation, e.g. sagital, coronal or axial") do |orientation|
    options[:orientation] = orientation
  end

  # opts.on("-s", "--studyInfo patfName,patlName,patId,studyDate, accessionNo", Array, "The study information for the report") do |study|
  #     options[:study] = study
  # end

end

option_parser.parse!

dicomdir=options[:dicomdir]
outputdir=options[:outputdir]

Dir.chdir "#{dicomdir}"
image = Dir.glob "*.dcm"
dcm = DObject.read("#{image[0]}")
studyInfo = dcm.value("0008,1030")
patName = dcm.value("0010,0010")
patId = dcm.value("0010,0020")
studyDate = dcm.value("0008,0020")
accessionNo = dcm.value("0008,0050")

patfName = patName[(patName =~ /\^/)+1, patName.length]
patlName = patName[0,patName =~ /\^/]

LHipp_label = 17
RHipp_label = 53
LAccu_label = 26
RAccu_label = 58
LAmyg_label = 18
RAmyg_label = 54
LCaud_label = 11
RCaud_label = 50
LPall_label = 13
RPall_label = 52
LPuta_label = 12
RPuta_label = 51
LThal_label = 10
RThal_label = 49


LabelColor = ChunkyPNG::Color.rgb(255,0,0)

# patfName = options[:study][0]
# patlName = options[:study][1]
# patId = options[:study][2]
# studyDate = options[:study][3]
#accessionNo = options[:study][4]
#dicomdir=options[:dicomdir]


# Decompress NIFTI .gz files
def decompress(filename)
  basename = File.basename(filename, '.nii.gz')
  dirname = File.dirname(filename)
  `gzip -d #{filename}`
  filename_d = dirname+'/'+basename+'.nii'
  return filename_d
end

def read_nifti(nii_file)
  NIFTI::NObject.new(nii_file, :narray => true).image.to_i
end

def get_2d_slice(ni3d, dim, slice_num,orientation)
  puts "Extracting 2D slice number #{slice_num} on dimension #{dim} for volume."
  #case orientation
    #when 'axial'
    if dim == 1
      ni3d[slice_num,true,true]
    elsif dim == 2
      ni3d[true,slice_num,true]
    elsif dim == 3
      ni3d[true,true,slice_num]
    else
      raise "No valid dimension specified for slice extraction"
    end
    #when 'sagital'
    #end
end

def normalise(x,xmin,xmax,ymin,ymax)
    xrange = xmax-xmin
    yrange = ymax-ymin
    ymin + (x-xmin) * (yrange.to_f / xrange)
end

def png_from_nifti_img(ni2d) # Create PNG object from NIFTI image NArray 2D Image
  puts "Creating PNG image for 2D nifti slice"
  # Create PNG
  png = ChunkyPNG::Image.new(ni2d.shape[0], ni2d.shape[1], ChunkyPNG::Color::TRANSPARENT)

  # Fill PNG with values from slice NArray
  png.height.times do |y|
    png.row(y).each_with_index do |pixel, x|
      val = ni2d[x,y]
      valnorm = normalise(val, ni2d.min, ni2d.max, 0, 255).to_i
      png[x,y] = ChunkyPNG::Color.rgb(valnorm, valnorm, valnorm)
    end
  end
  # return PNG
  return png
end

def generate_label_map_png(base_slice, label_slice,label) # Applies a label map over a base image
  base_png = png_from_nifti_img(base_slice)
  # Fill PNG with values from slice NArray
  base_png.height.times do |y|
    base_png.row(y).each_with_index do |pixel, x|
      val = label_slice[x,y]
      base_png[x,y] = LabelColor if val == label
    end
  end

  # return PNG
  return base_png
end

def generate_png_slice(nii_file, dim, slice)
  nifti = NIFTI::NObject.new(nii_file, :narray => true).image.to_i
  nifti_slice = get_2d_slice(nifti, dim, sel_slice)
  png = png_from_nifti_img(nifti_slice)
  return png
end

def coord_map(coord)
  lh = {} #LHipp_label
  rh = {} #RHipp_label
  lac = {} #LAccu_label
  rac = {} #RAccu_label
  lam = {} #LAmyg_label
  ram = {} #RAmyg_label
  lca = {} #LCaud_label
  rca = {} #RCaud_label 
  lpa = {} #LPall_label
  rpa = {} #RPall_label 
  lpu = {} #LPuta_label
  rpu = {} #RPuta_label
  lth = {} #LThal_label
  rha = {} #RThal_label


  axis = ["x", "y", "z"]

  (0..2).each do |i|
    lh[axis[i]] = coord[i].to_i.round
  end
  (3..5).each do |i|
    rh[axis[i-3]] = coord[i].to_i.round
  end

  (6..8).each do |i|
    lac[axis[i]] = coord[i].to_i.round
  end
  (9..11).each do |i|
    rac[axis[i-3]] = coord[i].to_i.round
  end

  (12..14).each do |i|
    lam[axis[i]] = coord[i].to_i.round
  end
  (15..17).each do |i|
    ram[axis[i-3]] = coord[i].to_i.round
  end

  (18..20).each do |i|
    lca[axis[i]] = coord[i].to_i.round
  end
  (21..23).each do |i|
    rca[axis[i-3]] = coord[i].to_i.round
  end

  (24..26).each do |i|
    lpa[axis[i]] = coord[i].to_i.round
  end
  (27..29).each do |i|
    rpa[axis[i-3]] = coord[i].to_i.round
  end

  (30..32).each do |i|
    lpu[axis[i]] = coord[i].to_i.round
  end
  (33..35).each do |i|
    rpu[axis[i-3]] = coord[i].to_i.round
  end

  (36..38).each do |i|
    lth[axis[i]] = coord[i].to_i.round
  end
  (39..41).each do |i|
    rth[axis[i-3]] = coord[i].to_i.round
  end

  return [lh,rh,lac,rac,lam,ram,lca,rca,lpa,rpa,lpu,rpu,lth,rth]
end
#### END METHODS ####

beginning_time = Time.now

# CONVERT DICOM TO NIFTI
`mcverter -f fsl -x -d -n -o  #{dicomdir} #{dicomdir}`

dirnewname= Dir.entries(dicomdir).select {|entry| File.directory? File.join(dicomdir,entry) and !(entry =='.' || entry == '..') }
dirniipath="#{dicomdir}/#{dirnewname[0]}"
dirniilist=Dir.entries(dirniipath).select {|entry| File.directory? File.join(dirniipath,entry) and !(entry =='.' || entry == '..') }
pathniilist="#{dirniipath}/#{dirniilist[0]}"
original_image=Dir["#{pathniilist}/*.nii"]

original_image=original_image[0]

# PERFORM BRAIN EXTRACTION
bet = FSL::BET.new(original_image, options[:dicomdir], {fi_threshold: 0.5, v_gradient: 0})
bet.command
bet_image = bet.get_result

case options[:orientation]
when 'sagital'
  `fslswapdim #{bet_image} -z -x y #{bet_image}`
when 'coronal'
  `fslswapdim #{bet_image} x -z y #{bet_image}`
end


# PERFORM 'FIRST' SEGMENTATION
#puts "hola #{options[:outputdir]}"
first = FSL::FIRST.new(bet_image, options[:outputdir]+'/test_brain_FIRST', {already_bet:true, structure: 'L_Hipp,R_Hipp,L_Accu,R_Accu,L_Amyg,R_Amyg,L_Caud,R_Caud,L_Pall,R_Pall,L_Puta,R_Puta,L_Thal,R_Thal'})
first.command
first_images = first.get_result

# Get center of gravity coordinates
cog_coords = FSL::Stats.new(first_images[:origsegs], true, {cog_voxel: true}).command.split
lh_cog, rh_cog, lac_cog, rac_cog, lam_cog, ram_cog, lca_cog, rca_cog, lpa_cog, rpa_cog, lpu_cog, rpu_cog, lth_cog, rth_cog = coord_map(cog_coords)
puts "Left Hippocampus center of gravity voxel coordinates: #{lh_cog}"
puts "Right Hippocampus center of gravity voxel coordinates: #{rh_cog}"

# Get Hippocampal volumes
lhipp_vol_mm = FSL::Stats.new(first_images[:firstseg], false, {low_threshold: LHipp_label - 0.5, up_threshold: LHipp_label + 0.5, voxels_nonzero: true}).command.split[1]
lhipp_vol = sprintf('%.2f', (lhipp_vol_mm.to_f/1000))
puts "Left hippocampal volume: #{lhipp_vol}"

rhipp_vol_mm = FSL::Stats.new(first_images[:firstseg], false, {low_threshold: RHipp_label - 0.5, up_threshold: RHipp_label + 0.5, voxels_nonzero: true}).command.split[1]
rhipp_vol = sprintf('%.2f', (rhipp_vol_mm.to_f/1000))
puts "Right hippocampal volume: #{rhipp_vol}"

File.open("epicampus.txt", 'a') do |file|
  file << "#{accessionNo}\t#{lhipp_vol}\t#{rhipp_vol}\n"
end

# Decompress files
anatomico_nii = decompress(bet_image)
hipocampos_nii= decompress(first_images[:firstseg])

# Set  nifti file
anatomico_3d_nifti = read_nifti(anatomico_nii)
hipocampos_3d_nifti = read_nifti(hipocampos_nii)

(1..3).each do |sel_dim|
	# Left Hippocampus
	sel_slice = lh_cog.values[sel_dim-1]
 	lh_anatomico_2d_slice = get_2d_slice(anatomico_3d_nifti, sel_dim, sel_slice, options[:orientation])
	lh_hipocampos_2d_slice = get_2d_slice(hipocampos_3d_nifti, sel_dim, sel_slice, options[:orientation])
	# Overlay hippocampus label map and flip for display
	lh_labeled_png = generate_label_map_png(lh_anatomico_2d_slice, lh_hipocampos_2d_slice, LHipp_label).flip_horizontally!
	# Save Labeled PNG
	lh_labeled_png.save("#{options[:outputdir]}/lh_#{sel_dim}_labeled.png")

	# Right Hippocampus
	sel_slice = rh_cog.values[sel_dim-1]
 	rh_anatomico_2d_slice = get_2d_slice(anatomico_3d_nifti, sel_dim, sel_slice, options[:orientation])
	rh_hipocampos_2d_slice = get_2d_slice(hipocampos_3d_nifti, sel_dim, sel_slice, options[:orientation])
	# Overlay hippocampus label map and flip for display
	rh_labeled_png = generate_label_map_png(rh_anatomico_2d_slice, rh_hipocampos_2d_slice, RHipp_label).flip_horizontally!
	# Save Labeled PNG
      rh_labeled_png.save("#{options[:outputdir]}/rh_#{sel_dim}_labeled.png")
end


# Generate PDF
Prawn::Document.generate("#{options[:outputdir]}/report.pdf") do |pdf|
  # Title
  pdf.text "Reporte de analisis del volumen hipocampal" , size: 15, style: :bold, :align => :center
  pdf.move_down 15

  # Report Info
  #pdf.formatted_text [ { :text => "Codigo: ", :styles => [:bold], size: 10 }, { :text => "#{accessionNo}", size: 10 }]
  pdf.formatted_text [ { :text => "Nombre del paciente: ", :styles => [:bold], size: 10 }, { :text => "#{patfName} #{patlName}", :styles => [:bold], size: 10 }]
  pdf.formatted_text [ { :text => "Identificacion del Paciente: ", :styles => [:bold], size: 10 }, { :text => "#{patId}", size: 10 }]
  pdf.formatted_text [ { :text => "Fecha de nacimiento: ", :styles => [:bold], size: 10 }, { :text => "#{studyDate}", size: 10 }]
  pdf.move_down 20

  # SubTitle RH
  pdf.text "Hipocampo Derecho" , size: 13, style: :bold, :align => :center
  pdf.move_down 5

  # Images RH
  pdf.image "#{options[:outputdir]}/rh_3_labeled.png", :width => 200, :height => 200, :position => 95
  pdf.move_up 200
  pdf.image "#{options[:outputdir]}/rh_2_labeled.png", :width => 150, :height => 100, :position => 295
  pdf.image "#{options[:outputdir]}/rh_1_labeled.png", :width => 150, :height => 100, :position => 295
  pdf.move_down 20

  # SubTitle LH
  pdf.text "Hipocampo izquierdo" , size: 13, style: :bold, :align => :center
  pdf.move_down 5

  # Images LH
  pdf.image "#{options[:outputdir]}/lh_3_labeled.png", :width => 200, :height => 200, :position => 95
  pdf.move_up 200
  pdf.image "#{options[:outputdir]}/lh_2_labeled.png", :width => 150, :height => 100, :position => 295
  pdf.image "#{options[:outputdir]}/lh_1_labeled.png", :width => 150, :height => 100, :position => 295
  pdf.move_down 40

  #Volumes Table New

  volumesTable = [["Volumen del hipocampo derecho:  #{rhipp_vol} cm3", "Volumen del hipocampo izquierdo:  #{lhipp_vol} cm3"]]
  pdf.table volumesTable, column_widths: [270,270], cell_style:  {padding: 12, height: 40}
  # Volumes Table
  #pdf.table([ ["Volumen del hipocampo derecho", "#{rhipp_vol} cm3"],
  #   


end

end_time = Time.now
puts "Time elapsed #{(end_time - beginning_time)} seconds"