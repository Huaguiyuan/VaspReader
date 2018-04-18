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
		if(@dyn == true)
			puts("Selective dynamics flag has already set.")
		else
			@dyn = true
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
		@dyn      = (poscar_str[7][0].casecmp("s") == 0)
		if ( @dyn == false )
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
# normalize unit
#=========================================================================================

	def normalize()
		 atom_crd.map!{ |a|
		 	a.map{ |f|
				if(f < 0) 
					f + 1
				elsif(f >=1)
					f - 1 
				else 
					f
				end 
			}
		}
	end
	
	def unnormalize(ref_filename)
		refcar = VaspReader.new(ref_filename)
		
		check_poscar_correspond( "unnormalize", refcar )
		
		atom_crd.map!.with_index{ |a, i|
			a.map.with_index{ |f, j|
				if((f - refcar.atom_crd[i][j]).abs > 0.5)
					if(f < 0.5)
						f + 1
					elsif(f >= 0.5)
						f - 1
					end
				else
					f
				end
			}
		}
	end
	
#=========================================================================================
# editing unit
#=========================================================================================

#=========================================================================================
# gen_sup -- A method to generate supercell with larger periodicities.
#=========================================================================================

	def gen_sup( sup_vec )
		@dyn = false
		if(@crd_sys.casecmp("direct") == 0)
			gen_sup_direct(sup_vec)
		elsif(@crd_sys.casecmp("cartesian") == 0)
			gen_sup_cartesian(sup_vec)
		end
		check_invalid_coordinates("gen_sup")
	end
	
	def gen_sup_direct( sup_vec )
		@atom_crd = gen_sup_direct_atom_crd( sup_vec )
		@atom_num = gen_sup_atom_num( sup_vec )
		@lattice  = gen_sup_lattice( sup_vec )
	end
	
	def gen_sup_cartesian( sup_vec )
		@atom_crd = gen_sup_cartesian_atom_crd( sup_vec )
		@atom_num = gen_sup_atom_num( sup_vec )
		# note: In gen_sup_cartesian method, @lattice must be processed at last.
		@lattice  = gen_sup_lattice( sup_vec )
	end
	
	def gen_sup_lattice( sup_vec )
		return @lattice.map.with_index{ |a, i| a.map{ |f| f * sup_vec[i] } }
	end
	
	def gen_sup_atom_num( sup_vec )
		return @atom_num.map{ |f| f * sup_vec.inject(1){ |product, i| product * i } }
	end

	def gen_sup_direct_atom_crd( sup_vec )
		gen_crd = []
		@atom_crd.length.times do |i|
			sup_vec[0].times do |a|
			sup_vec[1].times do |b|
			sup_vec[2].times do |c|
				gen_crd << [ \
					(@atom_crd[i][0] + a) / sup_vec[0], \
					(@atom_crd[i][1] + b) / sup_vec[1], \
					(@atom_crd[i][2] + c) / sup_vec[2]  \
				]
			end
			end
			end
		end
		return gen_crd
	end
	
	def gen_sup_cartesian_atom_crd( sup_vec )
		gen_crd = []
		@atom_crd.length.times do |i|
			sup_vec[0].times do |a|
			sup_vec[1].times do |b|
			sup_vec[2].times do |c|
				gen_crd << [ \
					@atom_crd[i][0] + a * lattice[0][0] + b * lattice[0][1] + c * lattice[0][2], \
					@atom_crd[i][1] + a * lattice[1][0] + b * lattice[1][1] + c * lattice[1][2], \
					@atom_crd[i][2] + a * lattice[2][0] + b * lattice[2][1] + c * lattice[2][2]  \
				]
			end
			end
			end
		end
		return gen_crd
	end
	
#=========================================================================================
# lerp_to -- A method to generate intermidiate structures by liner interpolation.
#=========================================================================================

	# note: Configuration of POSCAR (scale, lattice or dyn) written with this method reflects that of tocar.
	def lerp_to(min, max, interval, to_filename, ref_filename=@filename)
		tocar = VaspReader.new(to_filename)
		
		check_poscar_correspond( "lerp_to", tocar )
		
		tocar.unnormalize(ref_filename) unless(ref_filename == tocar.filename)
		unnormalize(ref_filename) unless(ref_filename == @filename)
		
		to_atom_crd = tocar.atom_crd
		
		index = 0
		while(min + interval * index <= max)
			gen_crd = atom_crd.map.with_index{ |a, i|
				a.map.with_index{ |s, j|
					( to_atom_crd[i][j] - s ) * ( min + interval * index ) + s
				}
			}
			tocar.atom_crd = gen_crd
			tocar.write_poscar( "POSCAR" + ( index + 1 ).to_s )
			index += 1
		end
	end

#=========================================================================================
# chacking/error unit
#=========================================================================================

	def check_invalid_coordinates( status )
		abort( "ERROR: Invalid coordinates in #{status}" ) unless( self.total_atom_num() == @atom_crd.length )
	end
	
	def check_poscar_correspond( status, car )
		abort( "ERROR: Some POSCARs do not correspond in #{status}" ) unless( self.total_atom_num() == car.total_atom_num() )
	end
	
end

__END__
