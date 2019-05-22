include("core.jl")
using SparseArrays
#creates the beta_v and beta_T from the vector specified
function gerg_betamatrix_from_vector(v,symmetric_op = (a)->a)
    N1 = length(v)
    N = Int64((1+sqrt(1+8*N1))/2) #the real size of the matrix, this will fail if x is not a vector with the values of
    #the diagonal
    A = Array{eltype(v),2}(undef,N,N)
    count=1
   @boundscheck checkbounds(A,N,N)
   @inbounds begin
        for i = 1 : N
            A[i,i] = 1.0
                for j = i+1 : N
                A[i,j] = v[count]
                A[j,i] = symmetric_op(v[count])
                count+=1
            end
        end
   end
    return A
end

struct GERG2008 <: AbstractHelmholtzModel
    N::Int64
    molecularWeight::Array{Float64,1}
    criticalDensity::Array{Float64,1}
    criticalTemperature::Array{Float64,1}
    ideal_iters::Array{Array{Int64,1},1}
    nr::Array{Float64,2}
    zeta::Array{Float64,2}
    n0ik::Array{Array{Float64,1},1}
    t0ik::Array{Array{Float64,1},1}
    d0ik::Array{Array{Float64,1},1}
    c0ik::Array{Array{Float64,1},1}
    k_pol_ik::Array{Int64,1}
    k_exp_ik::Array{Int64,1}
    gamma_v::Array{Float64,2}
    gamma_T::Array{Float64,2}
    beta_v::Array{Float64,2}
    beta_T::Array{Float64,2}
    Aij_indices::SparseArrays.SparseMatrixCSC{Int64,Int64}
    fij::Array{Float64,1}
    dijk::Array{Array{Float64,1},1}
    tijk::Array{Array{Float64,1},1}
    nijk::Array{Array{Float64,1},1}
    etaijk::Array{Array{Float64,1},1}
    epsijk::Array{Array{Float64,1},1}
    betaijk::Array{Array{Float64,1},1}
    gammaijk::Array{Array{Float64,1},1}
    k_pol_ijk::Array{Int64,1}
    k_exp_ijk::Array{Int64,1}
    function GERG2008(xsel = collect(1:21))

        N=length(xsel)

        molecularWeight = [16.04246,28.0134,44.0095,30.06904,44.09562,58.1222,58.1222,72.14878,72.14878,86.17536,100.20194,
        114.22852,128.2551,142.28168,2.01588,31.9988,28.0101,18.01528,34.08088,4.002602,39.948]
        criticalTemperature = [190.564,126.192,304.1282,305.322,369.825,407.817,425.125,460.35,469.7,507.82,540.13,
        569.32,594.55,617.7,33.19,154.595,132.86,647.096,373.1,5.1953,150.687]
        criticalDensity =[10.139342719,11.1839,10.624978698,6.87085454,5.000043088,3.86014294,
        3.920016792,3.271,3.215577588,2.705877875,2.315324434,2.056404127,1.81,
        1.64,14.94,13.63,10.85,17.87371609,10.19,17.399,13.407429659] #molar density, in mol/dm3

        #iterations for the ideal part, for now i can´t design a general function
        #with alternating indices like in this form.
        iter_ideal = [4, 3, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 4, 2, 2, 3, 2, 0, 0]
        #original order
        iter4 = (findall(z->z==4,iter_ideal[xsel]))
        iter3 = (findall(z->z==3,iter_ideal[xsel]))
        iter2 = (findall(z->z==2,iter_ideal[xsel]))
        iter0 = (findall(z->z==0,iter_ideal[xsel]))
        ideal_iters = [iter4,iter3,iter2,iter0]




        nr = hcat([19.597508817,-83.959667892,3.00088,0.76315,0.00460,8.74432,-4.46921], #methane
        [11.083407489,-22.202102428,2.50031,0.13732,-0.14660,0.90066,0.0] ,     #nitrogen
        [11.925152758,-16.118762264,2.50002,2.04452,-1.06044,2.03366,0.01393],  #carbon dioxide
        [24.675437527,-77.425313760,3.00263,4.33939,1.23722,13.19740,-6.01989], #ethane
        [31.602908195,-84.463284382,3.02939,6.60569,3.19700,19.19210,-8.37267], #propane
        [20.884143364,-91.638478026,3.33944,9.44893,6.89406,24.46180,14.78240], #n-butane
        [20.413726078,-94.467620036,3.06714,8.97575,5.25156,25.14230,16.13880], #iso-butane
        [14.536611217,-89.919548319,3.00000,8.95043,21.83600,33.40320,0.0],     #n-pentane
        [15.449907693,-101.298172792,3.00000,11.76180,20.11010,33.16880,0.0],   #isopentane
        [14.345969349,-96.165722367,3.00000,11.69770,26.81420,38.61640,0.0],    #n-hexane
        [15.063786601,-97.345252349,3.00000,13.72660,30.47070,43.55610,0.0],    #n-heptane
        [15.864687161,-97.370667555,3.00000,15.68650,33.80290,48.17310,0.0],   #n-octane
        [16.313913248,-102.160247463,3.00000,18.02410,38.12350,53.34150,0.0],  #n-nonane
        [15.870791919,-108.858547525,3.00000,21.00690,43.49310,58.36570,0.0],       #n-decane
        [13.796443393,-175.864487294,1.47906,0.95806,0.45444,1.56039,-1.37560], #hydrogen
        [10.001843586,-14.996095135,2.50146,1.07558,1.01334,0.0,0.0],           #oxygen
        [10.813340744,-19.834733959,2.50055,1.02865,0.00493,0.0,0.0],           #carbon monoxide
        [8.203520690,-11.996306443,3.00392,0.01059,0.98763,3.06904,0.0],            #water
        [9.336197742,-16.266508995,3.00000,3.11942,1.00243,0.0,0.0],            #hydrogen sulfide
        [13.628409737,-143.470759602,1.50000,0.0,0.0,0.0,0.0],                  #helium
        [8.316631500,-4.946502600,1.50000,0.0,0.0,0.0,0.0]                      #argon
        )

        zeta = hcat([4.306474465,0.936220902,5.577233895,5.722644361],                  #methane
        [5.251822620,-5.393067706,13.788988208,0],                        #nitrogen
        [3.022758166,-2.844425476,1.589964364,1.121596090],                 #carbon dioxide
        [1.831882406,0.731306621,3.378007481,3.508721939],                  #ethane
        [1.297521801,0.543210978,2.583146083,2.777773271],                  #propane
        [1.101487798,0.431957660,4.502440459,2.124516319],                  #n-butane
        [1.074673199,0.485556021,4.671261865,2.191583480],                  #isobutane
        [0.380391739,1.789520971,3.777411113,0],                          #n-pentane
        [0.635392636,1.977271641,4.169371131,0],                          #isopentane
        [0.359036667,1.691951873,3.596924107,0],                          #n-hexane
        [0.314348398,1.548136560,3.259326458,0],                          #n-heptane
        [0.279143540,1.431644769,2.973845992,0],                          #n-octane
        [0.263819696,1.370586158,2.848860483,0],                          #n-nonane
        [0.267034159,1.353835195,2.833479035,0],                          #n-decane
        [6.891654113,9.847634830,49.765290750,50.367279301],                #hydrogen
        [14.461722565,7.223325463,0,0],                                 #oxygen
        [11.669802800,5.302762306,0,0],                                 #carbon monoxide
        [0.415386589,1.763895929,3.874803739,0],                          #water
        [4.914580541,2.270653980,0,0],                                  #hydrogen sulfide
        [0.0,0,0.0,0.0],                                                  #helium
        [0.0,0,0.0,0.0]                                                   #argon
        )

        n0ik=[[0.57335704239162,-0.16760687523730e1,0.23405291834916,-0.21947376343441,0.16369201404128e-1,
        0.15004406389280e-1,0.98990489492918e-1,0.58382770929055,-0.74786867560390,0.30033302857974,0.20985543806568,
        -0.18590151133061e-1,-0.15782558339049,0.12716735220791,-0.32019743894346e-1,-0.68049729364536e-1,0.24291412853736e-1,
        0.51440451639444e-2,-0.19084949733532e-1,0.55229677241291e-2,-0.44197392976085e-2,0.40061416708429e-1,-0.33752085907575e-1,
        -0.25127658213357e-2],#methane
        [0.59889711801201,-0.16941557480731e1,0.24579736191718,-0.23722456755175,0.17954918715141e-1,0.14592875720215e-1,0.10008065936206,
        0.73157115385532,-0.88372272336366,0.31887660246708,0.20766491728799,-0.19379315454158e-1,-0.16936641554983,0.13546846041701,
        -0.33066712095307e-1,-0.60690817018557e-1,0.12797548292871e-1,0.58743664107299e-2,-0.18451951971969e-1,0.47226622042472e-2,
        -0.52024079680599e-2,0.43563505956635e-1,-0.36251690750939e-1,-0.28974026866543e-2],#nitrogen
        [0.52646564804653,-0.14995725042592e1,0.27329786733782,0.12949500022786,0.15404088341841,-0.58186950946814,-0.18022494838296,
        -0.95389904072812e-1,-0.80486819317679e-2,-0.35547751273090e-1,-0.28079014882405,-0.82435890081677e-1,0.10832427979006e-1,
        -0.67073993161097e-2,-0.46827907600524e-2,-0.28359911832177e-1,0.19500174744098e-1,-0.21609137507166,0.43772794926972,
        -0.22130790113593,0.15190189957331e-1,-0.15380948953300e-1],#carbon_dioxide
        [0.63596780450714,-0.17377981785459e1,0.28914060926272,-0.33714276845694,0.22405964699561e-1,0.15715424886913e-1,0.11450634253745,
        0.10612049379745e1,-0.12855224439423e1,0.39414630777652,0.31390924682041,-0.21592277117247e-1,-0.21723666564905,-0.28999574439489,
        0.42321173025732,0.46434100259260e-1,-0.13138398329741,0.11492850364368e-1,-0.33387688429909e-1,0.15183171583644e-1,
        -0.47610805647657e-2,0.46917166277885e-1,-0.39401755804649e-1,-0.32569956247611e-2],#ethane
        [.10403973107358e1,-0.28318404081403e1,0.84393809606294,-0.76559591850023e-1,0.94697373057280e-1,0.24796475497006e-3,0.27743760422870,
        -0.43846000648377e-1,-0.26991064784350,-0.69313413089860e-1,-0.29632145981653e-1,0.14040126751380e-1],#propane
        [0.10626277411455e1,-0.28620951828350e1,0.88738233403777,-0.12570581155345,0.10286308708106,0.25358040602654e-3,0.32325200233982,
        -0.37950761057432e-1,-0.32534802014452,-0.79050969051011e-1,-0.20636720547775e-1,0.57053809334750e-2],#n-butane
        [0.10429331589100e1,-0.28184272548892e1,0.86176232397850,-0.10613619452487,0.98615749302134e-1,0.23948208682322e-3,0.30330004856950,
        -0.41598156135099e-1,-0.29991937470058,-0.80369342764109e-1,-0.29761373251151e-1,0.13059630303140e-1],#isobutane
        [0.10968643098001e1,-0.29988888298061e1,0.99516886799212,-0.16170708558539,0.11334460072775,
        0.26760595150748e-3,0.40979881986931,-0.40876423083075e-1,-0.38169482469447,-0.10931956843993,
        -0.32073223327990e-1,0.16877016216975e-1],#n-pentane
        [0.10963e1,-0.30402e1,0.10317e1,-0.15410,0.11535,0.29809e-3,0.39571,-0.45881e-1,-0.35804,-0.10107,
        -0.35484e-1,0.18156e-1],#isopentane
        [0.10553238013661e1,-0.26120615890629e1,0.76613882967260,-0.29770320622459,0.11879907733358,0.27922861062617e-3,
        0.46347589844105,0.11433196980297e-1,-0.48256968738131,-0.93750558924659e-1,-0.67273247155994e-2,-0.51141583585428e-2],#n-hexane
        [0.10543747645262e1,-0.26500681506144e1,0.81730047827543,-0.30451391253428,0.12253868710800,0.27266472743928e-3,0.49865825681670,
        -0.71432815084176e-3,-0.54236895525450,-0.13801821610756,-0.61595287380011e-2,0.48602510393022e-3],#n-heptane
        [0.10722544875633e1,-0.24632951172003e1,0.65386674054928,-0.36324974085628,0.12713269626764,0.30713572777930e-3,0.52656856987540,
        0.19362862857653e-1,-0.58939426849155,-0.14069963991934,-0.78966330500036e-2,0.33036597968109e-2],#n-octane
        [0.11151e1,-0.27020e1,0.83416,-0.38828,0.13760,0.28185e-3,0.62037,0.15847e-1,-0.61726,-0.15043,-0.12982e-1,0.44325e-2],#n-nonane
        [0.10461e1,-0.24807e1,0.74372,-0.52579,0.15315,0.32865e-3,0.84178,0.55424e-1,-0.73555,-0.18507,-0.20775e-1,0.12335e-1],#n-decane
        [0.53579928451252e1,-0.62050252530595e1,0.13830241327086,-0.71397954896129e-1,0.15474053959733e-1,-0.14976806405771,
        -0.26368723988451e-1,0.56681303156066e-1,-0.60063958030436e-1,-0.45043942027132,0.42478840244500,-0.21997640827139e-1,
        -0.10499521374530e-1,-0.28955902866816e-2],#hydrogen
        [0.88878286369701,-0.24879433312148e1,0.59750190775886,0.96501817061881e-2,0.71970428712770e-1,0.22337443000195e-3,
        0.18558686391474,-0.38129368035760e-1,-0.15352245383006,-0.26726814910919e-1,-0.25675298677127e-1,0.95714302123668e-2],#oxygen
        [0.90554,-0.24515e1,0.53149,0.24173e-1,0.72156e-1,0.18818e-3,0.19405,-0.43268e-1,-0.12778,-0.27896e-1,-0.34154e-1,0.16329e-1],#carbon_monoxide
        [0.82728408749586,-0.18602220416584e1,-0.11199009613744e1,0.15635753976056,0.87375844859025,-0.36674403715731,
        0.53987893432436e-1,0.10957690214499e1,0.53213037828563e-1,0.13050533930825e-1,-0.41079520434476,0.14637443344120,
        -0.55726838623719e-1,-0.11201774143800e-1,-0.66062758068099e-2,0.46918522004538e-2],#water
        [0.87641,-0.20367e1,0.21634,-0.50199e-1,0.66994e-1,0.19076e-3,0.20227,-0.45348e-2,-0.22230,-0.34714e-1,-0.14885e-1,0.74154e-2],#hydrogen_sulfide
        [-0.45579024006737,0.12516390754925e1,-0.15438231650621e1,0.20467489707221e-1,-0.34476212380781,-0.20858459512787e-1,
        0.16227414711778e-1,-0.57471818200892e-1,0.19462416430715e-1,-0.33295680123020e-1,-0.10863577372367e-1,-0.22173365245954e-1],#helium
        [0.85095714803969,-0.24003222943480e1,0.54127841476466,0.16919770692538e-1,0.68825965019035e-1,0.21428032815338e-3,0.17429895321992,
        -0.33654495604194e-1,-0.13526799857691,-0.16387350791552e-1,-0.24987666851475e-1,0.88769204815709e-2]#argon
        ]

        #most_compounds
        c0ik1=[1,1,2,2,3,3]
        d0ik1=[1,1,1,2,3,7,2,5,1,4,3,4]
        t0ik1=[0.250,1.125,1.500,1.375,0.250,0.875,0.625,1.750,3.625,3.625,14.500,12.000]
        k_exp_ik1 = length(c0ik1)
        k_pol_ik1 = length(d0ik1) - k_exp_ik1

        #methane,nitrogen,ethane
        c0ik2=[1,1,1,1,1,1,2,2,2,2,2,3,3,3,6,6,6,6]
        d0ik2=[1,1,2,2,4,4,1,1,1,2,3,6,2,3,3,4,4,2,3,4,5,6,6,7]
        t0ik2=[0.125,1.125,0.375,1.125,0.625,1.500,0.625,2.625,2.750,2.125,2.000,1.750,4.500,4.750,5.000,4.000,4.500,7.500,
        14.000,11.500,26.000,28.000,30.000,16.000]
        k_exp_ik2 = length(c0ik2)
        k_pol_ik2 = length(d0ik2) - k_exp_ik2

        #carbon_Dioxide
        c0ik3=[1,1,1,1,1,1,2,2,3,3,3,3,3,5,5,5,6,6]
        d0ik3=[1,1,2,3,3,3,4,5,6,6,1,4,1,1,3,3,4,5,5,5,5,5]
        t0ik3=[0.000,1.250,1.625,0.375,0.375,1.375,1.125,1.375,0.125,1.625,3.750,3.500,7.500,8.000,6.000,
        16.000,11.000,24.000,26.000,28.000,24.000,26.000]
        k_exp_ik3 = length(c0ik3)
        k_pol_ik3 = length(d0ik3) - k_exp_ik3
        #hydrogen
        c0ik4=[1,1,1,1,2,2,3,3,5]
        d0ik4=[1,1,2,2,4,1,5,5,5,1,1,2,5,1]
        t0ik4=[0.500,0.625,0.375,0.625,1.125,2.625,0.000,0.250,1.375,
        4.000,4.250,5.000,8.000,8.000]
        k_exp_ik4 = length(c0ik4)
        k_pol_ik4 = length(d0ik4) - k_exp_ik4

        #water
        c0ik5=[1,1,1,2,2,2,3,5,5]
        d0ik5=[1,1,1,2,2,3,4,1,5,5,1,2,4,4,1,1]
        t0ik5=[0.500,1.250,1.875,0.125,1.500,1.000,0.750,1.500,0.625,2.625,5.000,4.000,4.500,3.000,4.000,6.000]
        k_exp_ik5 = length(c0ik5)
        k_pol_ik5 = length(d0ik5) - k_exp_ik5

        #helium
        c0ik6=[1,1,1,1,1,2,3,3]
        d0ik6=[1,1,1,4,1,3,5,5,5,2,1,2]
        t0ik6=[0.000,0.125,0.750,1.000,0.750,2.625,0.125,1.250,2.000,1.000,4.500,5.000]
        k_exp_ik6 = length(c0ik6)
        k_pol_ik6 = length(d0ik6) - k_exp_ik6

        c0ik = [c0ik2,c0ik2,c0ik3,c0ik2,c0ik1,
                c0ik1,c0ik1,c0ik1,c0ik1,c0ik1,
                c0ik1,c0ik1,c0ik1,c0ik1,c0ik4,
                c0ik1,c0ik1,c0ik5,c0ik1,c0ik6,
                c0ik1]

        d0ik = [d0ik2,d0ik2,d0ik3,d0ik2,d0ik1,
                d0ik1,d0ik1,d0ik1,d0ik1,d0ik1,
                d0ik1,d0ik1,d0ik1,d0ik1,d0ik4,
                d0ik1,d0ik1,d0ik5,d0ik1,d0ik6,
                d0ik1]

        t0ik = [t0ik2,t0ik2,t0ik3,t0ik2,t0ik1,
                t0ik1,t0ik1,t0ik1,t0ik1,t0ik1,
                t0ik1,t0ik1,t0ik1,t0ik1,t0ik4,
                t0ik1,t0ik1,t0ik5,t0ik1,t0ik6,
                t0ik1]

        k_pol_ik = vcat(k_pol_ik2,k_pol_ik2,k_pol_ik3,k_pol_ik2,k_pol_ik1,
                    k_pol_ik1,k_pol_ik1,k_pol_ik1,k_pol_ik1,k_pol_ik1,
                    k_pol_ik1,k_pol_ik1,k_pol_ik1,k_pol_ik1,k_pol_ik4,
                    k_pol_ik1,k_pol_ik1,k_pol_ik5,k_pol_ik1,k_pol_ik6,
                    k_pol_ik1)

        k_exp_ik = vcat(k_exp_ik2,k_exp_ik2,k_exp_ik3,k_exp_ik2,k_exp_ik1,
                    k_exp_ik1,k_exp_ik1,k_exp_ik1,k_exp_ik1,k_exp_ik1,
                    k_exp_ik1,k_exp_ik1,k_exp_ik1,k_exp_ik1,k_exp_ik4,
                    k_exp_ik1,k_exp_ik1,k_exp_ik5,k_exp_ik1,k_exp_ik6,
                    k_exp_ik1)

        fgammat = (a,b) -> 0.5*(a+b)/sqrt(a*b)
        fgammav = (a,b) -> 4*(a+b)/(a^(1/3)+b^(1/3))^3

        gamma_T = mixing_matrix(fgammat,criticalTemperature)

        gamma_v = mixing_matrix(fgammav,1 ./ criticalDensity)

        vector_beta_v=[0.9987213770,0.9995180720,0.9975478660,1.0048270700,0.9791059720,
        1.0112403880,0.9483301200,1.0000000000,0.9580152940,0.9620508310,0.9947406030,
        1.0028522870,1.0330862920,1.0000000000,1.0000000000,0.9973407720,1.0127831690,
        1.0125990870,1.0000000000,1.0346302590,0.9777946340,0.9788801680,0.9744246810,
        0.9960826100,0.9864158300,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,0.9725320650,1.0000000000,1.0000000000,
        0.9995217700,0.9103942490,0.9695010550,1.0041664120,1.0025257180,0.9968980040,
        1.1747609230,1.0765518820,1.0243114980,1.0607931040,1.0000000000,1.2054699760,
        1.0261693730,1.0000000000,1.0001511320,0.9041421590,1.0000000000,1.0000000000,
        0.9490559590,0.9066305640,0.8466475610,1.0083924280,0.9976072770,0.9991572050,
        1.0000000000,0.9938510090,1.0000000000,1.0000000000,1.0000000000,1.0074697260,
        1.0000000000,0.9956762580,0.9253671710,1.0000000000,1.0000000000,1.0000000000,
        1.0108179090,1.0000000000,1.0000000000,0.9997958680,0.9992431460,1.0449194310,
        1.0404592890,1.0000000000,1.0000000000,1.0000000000,1.0000000000,0.9841042270,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,0.9368112190,1.0000000000,
        1.0000000000,1.0008804640,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,0.9769519680,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,0.9081131630,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0129944310,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,0.9846132030,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0015163710,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,0.7544739580,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,0.8289671640,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.6953583820,1.0000000000,1.0000000000,
        1.0000000000,0.9751877660,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000,1.0000000000,0.9997468470,1.0000000000,0.7956603920,1.0000000000,
        1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,1.0000000000,
        1.0000000000]

        beta_v=gerg_betamatrix_from_vector(vector_beta_v,x->1/x)

        vector_beta_T = [0.998098830,1.022624490,0.996336508,0.989680305,0.994174910,
        0.980315756,0.992127525,1.0,0.981844797,0.977431529,0.957473785,0.947716769,
        0.937777823,1.0,1.0,0.987411732,1.063333913,1.011090031,1.0,0.990954281,
        1.005894529,1.007671428,1.002677329,0.994515234,0.992868130,1.0,1.0,1.0,1.0,
        1.0,0.956379450,0.957934447,0.946134337,1.0,1.0,0.997190589,1.004692366,
        0.692868765,0.999069843,1.013871147,1.033620538,1.018171004,1.023339824,
        1.027000795,1.019180957,1.0,1.011806317,1.029690780,1.007688620,1.020028790,
        0.942320195,1.0,1.0,0.997372205,1.016034583,0.768377630,0.996512863,
        0.996199694,0.999130554,1.0,0.998688946,1.0,1.0,1.0,0.984068272,1.0,
        0.970918061,0.932969831,1.0,1.0,1.0,0.990197354,1.0,1.0,1.000310289,
        0.998012298,0.996484021,0.994364425,1.0,1.0,1.0,1.0,0.985331233,1.0,1.0,1.0,
        1.0,0.992573556,1.0,1.0,1.000077547,1.0,1.0,1.0,1.0,1.0,1.0,0.993688386,1.0,
        1.0,1.0,1.0,0.985962886,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,
        0.974550548,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.962006651,1.0,
        1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.997641010,
        1.0,1.0,1.0,1.0,0.985891113,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.988937417,
        1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,
        1.064818089,1.0,1.049594632,0.897162268,0.973091413,1.0,1.0,1.0,1.0,1.0,1.0,
        1.0,1.0,1.0,1.0,1.0,1.0,1.000023103,1.0,1.025536736,1.0,1.0,1.0,1.0,1.0,1.0,
        1.0,1.0]

        beta_T=gerg_betamatrix_from_vector(vector_beta_T,x->1/x)

        indice1 = [1,1,1,1,1,1,1,2,2,4,4,4,5,5,6]
        indice2 = [2,3,4,5,6,7,15,3,4,5,6,7,6,7,7]
        value_eq = 1:length(indice1)

        Aij_indices = SparseArrays.spzeros(Int64,21,21)

        for i = 1:length(value_eq)
           Aij_indices[indice1[i],indice2[i]] = value_eq[i]
        end

        fij=[1.0,1.0,1.0,1.0,1.0,0.771035405688,1.0,1.0,1.0,0.130424765150,0.281570073085,0.260632376098,
        0.312572600489e-1,-0.551609771024e-1,-0.551240293009e-1]

        dijk=[[1,4,1,2,2,2,2,2,3],
        [1,2,3,1,2,3],
        [3,4,1,2,2,2,2,2,2,3,3,3],
        [3,3,4,4,4,1,1,1,2],
        [2,3,1,1,1,2],
        [2,2,3,1,2,2],
        [1,3,3,4],
        [1,1,1,2,2,3,3,4,4,4],
        [1,1,1,2,2,3,3,4,4,4],
        [1,1,1,2,2,3,3,4,4,4],
        [1,1,1,2,2,3,3,4,4,4],
        [1,1,1,2,2,3,3,4,4,4],
        [1,1,1,2,2,3,3,4,4,4],
        [1,1,1,2,2,3,3,4,4,4],
        [1,1,1,2,2,3,3,4,4,4]]

        tijk=[[0.000,1.850,7.850,5.400,0.000,0.750,2.800,4.450,4.250],
        [2.600,1.950,0.000,3.950,7.950,8.000],
        [0.650,1.550,3.100,5.900,7.050,3.350,1.200,5.800,2.700,0.450,0.550,1.950],
        [1.850,3.950,0.000,1.850,3.850,5.250,3.850,0.200,6.500],
        [1.850,1.400,3.200,2.500,8.000,3.750],
        [0.000,0.050,0.000,3.650,4.900,4.450],
        [2.0,-1.0,1.75,1.4],
        [1.000,1.550,1.700,0.250,1.350,0.000,1.250,0.000,0.700,5.400],
        [1.000,1.550,1.700,0.250,1.350,0.000,1.250,0.000,0.700,5.400],
        [1.000,1.550,1.700,0.250,1.350,0.000,1.250,0.000,0.700,5.400],
        [1.000,1.550,1.700,0.250,1.350,0.000,1.250,0.000,0.700,5.400],
        [1.000,1.550,1.700,0.250,1.350,0.000,1.250,0.000,0.700,5.400],
        [1.000,1.550,1.700,0.250,1.350,0.000,1.250,0.000,0.700,5.400],
        [1.000,1.550,1.700,0.250,1.350,0.000,1.250,0.000,0.700,5.400],
        [1.000,1.550,1.700,0.250,1.350,0.000,1.250,0.000,0.700,5.400],
        ]

        nijk=[[-0.98038985517335e-2,0.42487270143005e-3,-0.34800214576142e-1,-0.13333813013896,
        -0.11993694974627e-1,0.69243379775168e-1,-0.31022508148249,0.24495491753226,0.22369816716981],
        [-0.10859387354942,0.80228576727389e-1,-0.93303985115717e-2,0.40989274005848e-1,
        -0.24338019772494,0.23855347281124],
        [-0.80926050298746e-3,-0.75381925080059e-3,-0.41618768891219e-1,-0.23452173681569,0.14003840584586,
        0.63281744807738e-1,-0.34660425848809e-1,-0.23918747334251,0.19855255066891e-2,0.61777746171555e1,
        -0.69575358271105e1,0.10630185306388e1],
        [0.13746429958576e-1,-0.74425012129552e-2,-0.45516600213685e-2,-0.54546603350237e-2,0.23682016824471e-2,
        0.18007763721438,-0.44773942932486,0.19327374888200e-1,-0.30632197804624],
        [0.28661625028399,-0.10919833861247,-0.11374032082270e1,0.76580544237358,
        0.42638000926819e-2,0.17673538204534],
        [-0.47376518126608,0.48961193461001,-0.57011062090535e-2,-0.19966820041320,-0.69411103101723,0.69226192739021],
        [-0.25157134971934,-0.62203841111983e-2,0.88850315184396e-1,-0.35592212573239e-1],
        [0.25574776844118e1,-0.79846357136353e1,0.47859131465806e1,-0.73265392369587,0.13805471345312e1,
        0.28349603476365,-0.49087385940425,-0.10291888921447,0.11836314681968,0.55527385721943e-4],
        [0.25574776844118e1,-0.79846357136353e1,0.47859131465806e1,-0.73265392369587,0.13805471345312e1,
        0.28349603476365,-0.49087385940425,-0.10291888921447,0.11836314681968,0.55527385721943e-4],
        [0.25574776844118e1,-0.79846357136353e1,0.47859131465806e1,-0.73265392369587,0.13805471345312e1,
        0.28349603476365,-0.49087385940425,-0.10291888921447,0.11836314681968,0.55527385721943e-4],
        [0.25574776844118e1,-0.79846357136353e1,0.47859131465806e1,-0.73265392369587,0.13805471345312e1,
        0.28349603476365,-0.49087385940425,-0.10291888921447,0.11836314681968,0.55527385721943e-4],
        [0.25574776844118e1,-0.79846357136353e1,0.47859131465806e1,-0.73265392369587,0.13805471345312e1,
        0.28349603476365,-0.49087385940425,-0.10291888921447,0.11836314681968,0.55527385721943e-4],
        [0.25574776844118e1,-0.79846357136353e1,0.47859131465806e1,-0.73265392369587,0.13805471345312e1,
        0.28349603476365,-0.49087385940425,-0.10291888921447,0.11836314681968,0.55527385721943e-4],
        [0.25574776844118e1,-0.79846357136353e1,0.47859131465806e1,-0.73265392369587,0.13805471345312e1,
        0.28349603476365,-0.49087385940425,-0.10291888921447,0.11836314681968,0.55527385721943e-4],
        [0.25574776844118e1,-0.79846357136353e1,0.47859131465806e1,-0.73265392369587,0.13805471345312e1,
        0.28349603476365,-0.49087385940425,-0.10291888921447,0.11836314681968,0.55527385721943e-4]
        ]

        etaijk=[
        [1.000,1.000,0.250,0.000,0.000,0.000,0.000],
        [1.000,0.500,0.000],
        [1.000,1.000,1.000,0.875,0.750,0.500,0.000,0.000,0.000,0.000],
        [0.250,0.250,0.000,0.000],
        [0.250,0.250,0.000,0.000],
        [1.000,1.000,0.875],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[]
        ]

        epsijk=[[0.5,0.5,0.5,0.5,0.5,0.5,0.5],
        [0.5,0.5,0.5],
        [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5],
        [0.5,0.5,0.5,0.5],
        [0.5,0.5,0.5,0.5],
        [0.5,0.5,0.5],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[]
        ]
        betaijk=[[1.000,1.000,2.500,3.000,3.000,3.000,3.000],
        [1.000,2.000,3.000],
        [1.000,1.000,1.000,1.250,1.500,2.000,3.000,3.000,3.000,3.000],
        [0.750,1.000,2.000,3.000],
        [0.750,1.000,2.000,3.000],
        [1.000,1.000,1.250],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[]
        ]

        gammaijk=[[0.5,0.5,0.5,0.5,0.5,0.5,0.5],
        [0.5,0.5,0.5],
        [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5],
        [0.5,0.5,0.5,0.5],
        [0.5,0.5,0.5,0.5],
        [0.5,0.5,0.5],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[]
        ]


        length_k_ijk = length(dijk)
        k_pol_ijk = Array{Int64,1}(undef,length_k_ijk)
        k_exp_ijk = Array{Int64,1}(undef,length_k_ijk)
        for i = 1:length_k_ijk
            k_exp_ijk[i] = length(etaijk[i])
            k_pol_ijk[i] = length(dijk[i]) - k_exp_ijk[i]
        end
        return new(N,molecularWeight[xsel],criticalDensity[xsel],criticalTemperature[xsel],
        ideal_iters,nr[:,xsel],zeta[:,xsel],n0ik[xsel],t0ik[xsel],d0ik[xsel],c0ik[xsel],
        k_pol_ik[xsel],k_exp_ik[xsel],gamma_v[xsel,xsel],gamma_T[xsel,xsel],beta_v[xsel,xsel],beta_T[xsel,xsel],
        Aij_indices[xsel,xsel],fij,dijk,tijk,nijk,etaijk,epsijk,betaijk,gammaijk, k_pol_ijk,k_exp_ijk)
    end
end


function _f0(model::GERG2008,rho,T,x)


    RR = 8.314472/8.314510
    res = zero(eltype(rho))
    x0 = zero(eltype(x))  #for comparison
    ao1 =zero(eltype(T))
    ao2 =zero(eltype(T))
    ao_zero =zero(eltype(T))


    for i in model.ideal_iters[1]
        x[i] !=x0 && begin
        ao2 =ao_zero
        ao3 =ao_zero
        delta = rho/model.criticalDensity[i]
        tau = model.criticalTemperature[i]/T
        ao1 =  model.nr[1,i]+ model.nr[2,i]*tau + model.nr[3,i]*log(tau)
        ao2 = model.nr[4,i]*log(abs(sinh(model.zeta[1,i]*tau))) - model.nr[5,i]*log(cosh(model.zeta[2,i]*tau))+
        model.nr[6,i]*log(abs(sinh(model.zeta[3,i]*tau))) - model.nr[7,i]*log(cosh(model.zeta[4,i]*tau))
        ao3 = log(delta)
        a0 = RR*(ao1+ao2)+ao3
        res +=x[i]*(a0+log(x[i]))
    end
    end

    for i =model.ideal_iters[2]
        x[i] !=x0 && begin
        ao2 =ao_zero
        ao3 =ao_zero
        delta = rho/model.criticalDensity[i]
        tau = model.criticalTemperature[i]/T
        ao1 =  model.nr[1,i]+ model.nr[2,i]*tau + model.nr[3,i]*log(tau)
        ao2 = model.nr[4,i]*log(abs(sinh(model.zeta[1,i]*tau))) - model.nr[5,i]*log(cosh(model.zeta[2,i]*tau))+
        model.nr[6,i]*log(abs(sinh(model.zeta[3,i]*tau)))
        ao3 = log(delta)
        a0 = RR*(ao1+ao2)+ao3
        res +=x[i]*(a0+log(x[i]))
        end
    end

    for i in model.ideal_iters[3]
      x[i] !=x0 && begin
      ao2 =ao_zero
      ao3 =ao_zero
      delta = rho/model.criticalDensity[i]
      tau = model.criticalTemperature[i]/T
      ao1 =  model.nr[1,i]+ model.nr[2,i]*tau + model.nr[3,i]*log(tau)
      ao2 = model.nr[4,i]*log(abs(sinh(model.zeta[1,i]*tau))) - model.nr[5,i]*log(cosh(model.zeta[2,i]*tau))
      ao3 = log(delta)
      a0 = RR*(ao1+ao2)+ao3
      res +=x[i]*(a0+log(x[i]))
      end
    end

    for i in model.ideal_iters[4]
            x[i] !=x0 && begin
            ao2 =ao_zero
            ao3 =ao_zero
            delta = rho/model.criticalDensity[i]
            tau = model.criticalTemperature[i]/T
           # println((delta,tau))
            #println(ao1)
            ao1 =  model.nr[1,i]+ model.nr[2,i]*tau + model.nr[3,i]*log(tau)
            ao3 = log(delta)
            a0 = RR*(ao1)+ao3
            #println(model.nr[4,i]*log(abs(sinh(model.zeta[1,i]*tau))))
            #println(- model.nr[5,i]*log(cosh(model.zeta[2,i]*tau)))
            #println(model.nr[6,i]*log(abs(sinh(model.zeta[3,i]*tau))))
            res +=x[i]*(a0+log(x[i]))
            end
    end

        return res
end

_gerg_asymetric_mix_rule(xi,xj,b)= b*(xi+xj)/(xi*b^2+xj)


function _delta(model::GERG2008,rho,T,x)
    rhor = 1/mixing_rule_asymetric(power_mean_rule(3),_gerg_asymetric_mix_rule,
    x,  1 ./ model.criticalDensity,model.gamma_v,model.beta_v)
    return rho/rhor
end

function _tau(model::GERG2008,rho,T,x)
    Tr = mixing_rule_asymetric(geometric_mean_rule,_gerg_asymetric_mix_rule,
    x,model.criticalTemperature,model.gamma_T,model.beta_T)
    return Tr/T
end



function _fr1(model::GERG2008,delta,tau,x)
res =zero(eltype(delta))
res0 =zero(eltype(delta))
res1 =zero(eltype(delta))
x0 = zero(eltype(x))

for i = 1:model.N
    x[i]!=x0 && begin
        res1=res0
        for k = 1:model.k_pol_ik[i]
            res1+=model.n0ik[i][k]*
                (delta^model.d0ik[i][k])*
                (tau^model.t0ik[i][k])
        end

        for k = (model.k_pol_ik[i]+1):(model.k_exp_ik[i]+model.k_pol_ik[i])

            res1+=model.n0ik[i][k]*
                (delta^model.d0ik[i][k])*
                (tau^model.t0ik[i][k])*
                exp(-delta^model.c0ik[i][k-model.k_pol_ik[i]])
        end
        res+= x[i]*res1

    end
end

return res
end

function _fr2(model::GERG2008,delta,tau,x)
    res =zero(eltype(delta))
    res0 =zero(eltype(delta))
    res1 =zero(eltype(delta))
    x0 = zero(eltype(x))

    for kk in findall(!iszero, model.Aij_indices) # i are CartesianIndices
        i0 = model.Aij_indices[kk]
        i1 = kk[1]
        i2 = kk[2]
        x[i1] != x0 && x[i2] !=x0 && begin
        res1 = res0
        for j=1:model.k_pol_ijk[i0]
            res1 +=model.nijk[i0][j]*
            (delta^model.dijk[i0][j])*
            (tau^model.tijk[i0][j])
        end

        for j=(model.k_pol_ijk[i0]+1):(model.k_pol_ijk[i0]+model.k_exp_ijk[i0])


            idx = j-model.k_pol_ijk[i0]

            res1 +=model.nijk[i0][j]*
            (delta^model.dijk[i0][j])*
            (tau^model.tijk[i0][j])*
           exp(-model.etaijk[i0][idx]*(delta-model.epsijk[i0][idx])^2 -
            model.betaijk[i0][idx]*(delta-model.gammaijk[i0][idx]))
        end
        res+=res1*x[i1]*x[i2]*model.fij[i0]
    end
end
return res
end

function ideal_helmholtz(model::GERG2008,v,T,x)
    rho = 1.0e-3/v
    R= Unitful.ustrip(Unitful.R)
    return R*T*_f0(model,rho,T,x)
end

function residual_helmholtz(model::GERG2008,v,T,x)
    rho = 1.0e-3/v
    R= Unitful.ustrip(Unitful.R)
    delta = _delta(model,rho,T,x)
    tau = _tau(model,rho,T,x)
    return R*T*(_fr1(model,delta,tau,x)+_fr2(model,delta,tau,x))
end

function core_helmholtz(model::GERG2008,v,T,x)
    rho = 1.0e-3/v
    R= Unitful.ustrip(Unitful.R)
    delta = _delta(model,rho,T,x)
    tau = _tau(model,rho,T,x)
    return R*T*(_f0(model,rho,T,x)+_fr1(model,delta,tau,x)+_fr2(model,delta,tau,x))
end





#an interface to stract properties stored in the model, the minimum are:
#molecular weight (for the transformations mass/molar)
#critical temperature, pressure(for the transformations mass/molar)

###important! you can use whatever you want over the design of the model, but those functions
##interact with the rest of the model, so the have to be in SI units

compounds_number(model::GERG2008)=model.N
criticalDensity(model::GERG2008)=1000.0 .* model.criticalDensity
molecularWeight(model::GERG2008) = model.molecularWeight
criticalTemperature(model::GERG2008) = model.criticalTemperature
criticalVolume(model::GERG2008) = 1 ./criticalDensity(model)

#the function random_volume have to be implemented for stocastic solvers
min_volume(model::GERG2008,P0,T0,x0) = 0.2503*sum(criticalVolume(model) .*x0)
max_volume(model::GERG2008,P0,T0,x0) = 2*Unitful.ustrip(Unitful.R)*T0/P0


function random_volume(model::GERG2008,P0,T0,x0)
    min_v = min_volume(model,P0,T0,x0)
    max_v = max_volume(model,P0,T0,x0)

    return min_v + (max_v-min_v)*rand()
end
