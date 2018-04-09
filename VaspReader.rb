# -*- cording: utf-8 -*-

#=========================================================================================
# VaspReader -- Fundamental interface for manipulating POSCAR file by Ruby program,
#  coded by Taku MURAKAMI, graduate student at Shizuoka University
#=========================================================================================

class VaspReader

#=========================================================================================
# member-variable/accessor unit
#=========================================================================================

	attr_accessor(
		:filename, # read file name
		:title,    # comment line
		:scale,    # universal scaling factor
		:lattice,  # lattice vectors
		:atom,     # symbol of atoms
		:atom_num, # number of atoms
		:dyn,      # flag of 'Selective dynamics'
		:crd_sys,  # flag of coordination system ('Cartesian' or 'Direct')
		:atom_crd, # coordinates of atoms
		:dyn_crd   # coordinates of selective dynamics
	)
	
	def total_atom_num()
		return @total_atom_num = @atom_num.inject{ |sum, i| sum + i }
	end
	
	def change_crd_sys(new_crd_sys)
		unless(new_crd_sys.casecmp(@crd_sys) == 0)
			if(new_crd_sys.casecmp("direct") == 0)
				to_direct()
				return
			elsif(new_crd_sys.casecmp("cartesian") == 0 )
				to_cartesian()
				return
			else
				abort("ERROR: #{new_crd_sys} is not valid for vasp coordination system.")
			end
		end
		puts("#{new_crd_sys} has already been set.")
	end
	
	def to_direct()
		@crd_sys = "direct"
		@atom_crd = calc_direct_atom_crd( @atom_crd, @lattice )
	end
	
	def to_cartesian()
		@crd_sys = "cartesian"
		@atom_crd = calc_cartesian_atom_crd( @atom_crd, @lattice, @scale )
		@lattice.map!{ |a| a.map{ |f| f * @scale } }
		@scale = 1.0
	end
	
	def calc_direct_atom_crd( cartesian_atom_crd, lattice )
		abort( "ERROR: From cartesian to direct method has not been implemented yet, sorry!" )
	end
	
	def calc_cartesian_atom_crd( direct_atom_crd, lattice, scale=1.0 )
		cartesian_atom_crd = Array.new(total_atom_num()){ [] }
		total_atom_num().times do |i|
			3.times do |j|
				cartesian_atom_crd[i] << scale * ( direct_atom_crd[i][0] * lattice[0][j] \
				+ direct_atom_crd[i][1] * lattice[1][j] + direct_atom_crd[i][2] * lattice[2][j] )
			end
		end
		return cartesian_atom_crd
	end
	
	def set_dyn(init_dyn_crd=["T", "T", "T"])
		if(dyn == true)
			puts("Selective dynamics flag has already set.")
		else
			dyn = true
			set_dyn_crd(init_dyn_crd)
		end
	end
	
	def set_dyn_crd(dyn_crd=["T", "T", "T"])
		total_atom_num().times do |i|
			@dyn_crd[i] = dyn_crd
		end
	end
	
	def set_dyn_crd_with_range( range, dyn_crd=["T","T","T"] )
		total_atom_num().times do |i|
			unless( @atom_crd[i][0] >= range[0] && @atom_crd[i][0] < range[1] )
				next
			end
			unless( @atom_crd[i][1] >= range[2] && @atom_crd[i][1] < range[3] )
				next
			end
			unless( @atom_crd[i][2] >= range[4] && @atom_crd[i][2] < range[5] )
				next
			end
			@dyn_crd[i] = dyn_crd
		end
	end
	
	def show_all()
		puts(write_format().reject{ |s| s.nil? }.join("\n"))
	end
	
#=========================================================================================
# initialize/reading unit
#=========================================================================================

	def initialize( filename=nil )
		unless( filename == nil )
			@filename = filename
			read_file()
			check_invalid_coordinates( "initialize" )
		else
			abort("ERROR: In VaspReader, You must specify the file name to load.")
		end
	end
	
	def read_file()
		abort( "ERROR: #{@filename} not found" ) unless File.exist?( @filename )
		poscar_str = File.new( @filename, 'r' ).readlines.map{ |line| line.strip }.reject{ |line| line.empty? }
		read_poscar( poscar_str )
	end
	
	def read_poscar( poscar_str )
		@title    = poscar_str[0]
		@scale    = poscar_str[1].to_f
		@lattice  = poscar_str[2..4].map{ |line| line.split.map{ |s| s.to_f } }
		@atom     = poscar_str[5].split
		@atom_num = poscar_str[6].split.map{ |s| s.to_i }
		@dyn      = poscar_str[7][0].casecmp("s")
		if ( @dyn != 0 )
			@crd_sys  = poscar_str[7]
			@atom_crd = poscar_str[8..( total_atom_num() + 7 )].map{ |line| line.split[0..2].map{ |s| s.to_f } }
			@dyn_crd = Array.new( total_atom_num() ){ Array.new( 3, "F" ) }
		else
			@crd_sys  = poscar_str[8]
			@atom_crd    = poscar_str[9..( total_atom_num() + 8 )].map{ |line| line.split[0..2].map{ |s| s.to_f } }
			@dyn_crd = poscar_str[9..( total_atom_num() + 8 )].map{ |line| line.split[3..5].map{ |s| s } }
		end
	end
	
#=========================================================================================
# output/writing unit
#=========================================================================================

	def write_poscar( filename=@filename ) # default: over written
		File.write( filename, write_format().reject{ |s| s.nil? }.join("\n") )
	end
	
	
	def write_format() # default: VASP format
		poscar_str = []
		poscar_str << @title
		poscar_str << "  " + format( "% .13f", @scale ).to_s
		poscar_str << "    " + @lattice.to_a.map{ |a| a.map{ |f| format( "% .16f", f ).to_s }.join("   ") }.join("\n    ")
		poscar_str << "   " + @atom.join("   ")
		poscar_str << "  " + @atom_num.map{ |f| format( "%4d", f ).to_s }.join("  ")
		if ( @dyn == false )
			poscar_str << @crd_sys
			poscar_str << " " + @atom_crd.to_a.map{ |a| a.map{ |f| format( "% .16f", f ).to_s }.join(" ") } .join("\n ")
		else
			poscar_str << "Selective dynamics"
			poscar_str << @crd_sys
			total_atom_num().times do |i|
				poscar_str << " " + @atom_crd[i].map{ |f| format( "% .16f", f ).to_s }.join(" ") \
				+ "  " + @dyn_crd[i].map{ |s| s }.join("  ")
			end
		end
		poscar_str << ""
		return poscar_str
	end
	
#=========================================================================================
# chacking/error unit
#=========================================================================================

	def check_invalid_coordinates( status )
		abort( "ERROR: Invalid coordinates in #{status}" ) unless( self.total_atom_num() == @atom_crd.length )
	end
	
end

__END__
