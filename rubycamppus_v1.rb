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
LabelColor = ChunkyPNG::Color.rgb(255,0,0)

# patfName = options[:study][0]
# patlName = options[:study][1]
# patId = options[:study][2]
# studyDate = options[:study][3]
#accessionNo = options[:study][4]
#dicomdir=options[:dicomdir]
#outputdir=options[:outputdir]

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
  lh = {}
  rh = {}
  axis = ["x", "y", "z"]

  (0..2).each do |i|
    lh[axis[i]] = coord[i].to_i.round
  end

  (3..5).each do |i|
    rh[axis[i-3]] = coord[i].to_i.round
  end
  return [lh,rh]
end
#### END METHODS ####

beginning_time = Time.now

# CONVERT DICOM TO NIFTI
`mcverter -f fsl -x -d -n -o  #{dicomdir} #{dicomdir}`

dirnewname= Dir.entries(dicomdir).select {|entry| File.directory? File.join(dicomdir,entry) and !(entry =='.' || entry == '..') }
dirniipath="#{dicomdir}/#{dirnewname[0]}"
dirniilist=Dir.entries(dirniipath).select {|entry| File.directory? File.join(dirniipath,entry) and !(entry =='.' || entry == '..') }
pathniilist="#{dirniipath}/#{dirniilist[0]}"
original_image=Dir["#{pathniilist}*.nii"]

original_image=original_image[0]

# PERFORM BRAIN EXTRACTION
#`bet #{original_image} brain -v`
#`mv brain.nii.gz #{dicomdir}`

#case options[:orientation]
#when 'sagital'
#  `fslswapdim #{bet_image} -z -x y #{bet_image}`
#when 'coronal'
#  `fslswapdim #{bet_image} x -z y #{bet_image}`
#end

# PERFORM 'fsl_anat' SEGMENTATION

`fsl_anat -i #{original_image}`





end_time = Time.now
puts "Time elapsed #{(end_time - beginning_time)} seconds"