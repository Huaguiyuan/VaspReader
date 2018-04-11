# -*- cording: utf-8 -*-

#=========================================================================================
# adj_vacuum_layer -- A method to adjust the interval between two layers,
#  specified by "interlayer_point", with "expand_amount",
#  coded by Taku MURAKAMI, graduate student at Shizuoka University.
#=========================================================================================

require_relative( "./VaspReader.rb" )

def expand_vacuum_layer( poscar, interlayer_point, expand_amount )
	
	if(poscar.crd_sys != "cartesian")
		abort("ERROR: expand_vacuum_layer method is applicable to cartesian setting only.")
	end
	
	# expand interlaye distance
	poscar.atom_crd.map!{ |a|
		if( a[2] <= interlayer_point )
			a
		elsif( a[2] > interlayer_point )
			[a[0], a[1], a[2] + ( expand_amount )]
		end
	}
	
	# expand cellsize
	poscar.lattice[2][2] += 2 * expand_amount
end

#=========================================================================================
# main method
#=========================================================================================

if(__FILE__ == $0)
	30.times do |i|
		poscar = VaspReader.new( "POSCAR" )
		poscar.change_crd_sys("cartesian")
		expand_vacuum_layer( poscar, poscar.lattice[2][2] * 0.025, 0.05 * (i - 10) )
		poscar.write_poscar( "POSCAR" + (i + 1).to_s )
	end
end

__END__
