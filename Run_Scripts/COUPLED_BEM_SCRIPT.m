
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                 %%%
%%%       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     %%%
%%%       %%%%%% Written by Gabriel Scarlett August 2017 %%%%%%     %%%
%%%       %%%%%%     The University of Edinburgh, UK     %%%%%%     %%%
%%%       %%%%%%         School of Engineering           %%%%%%     %%%
%%%       %%%%%%       Institute for Energy Systems      %%%%%%     %%%
%%%       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     %%%
%%%                                                                 %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% ASSIGN PATHS TO FUNCTIONS AND DATA: WORK PC
path(path,genpath('\Users\s1040865\Dropbox\PhD\Modelling\Programs\Matlab\Working_Folder_April_2018\PATH\functions')); % Functions
path(path,genpath('\Users\s1040865\Dropbox\PhD\Modelling\Programs\Matlab\Working_Folder_April_2018\PATH\data')); % Input data
path(path,genpath('\Users\s1040865\Dropbox\PhD\Modelling\Programs\Matlab\Working_Folder_April_2018\PATH\Saved_Simulation_data')); % Saved simulation data
 
% ASSIGN PATHS TO FUNCTIONS AND DATA: HOME W520
path(path,genpath('\Users\gabsc\Dropbox\PhD\Modelling\Programs\Matlab\Working_Folder_April_2018\PATH\functions')); % Functions
path(path,genpath('\Users\gabsc\Dropbox\PhD\Modelling\Programs\Matlab\Working_Folder_April_2018\PATH\data')); % Input data
path(path,genpath('\Users\gabsc\Dropbox\PhD\Modelling\Programs\Matlab\Working_Folder_April_2018\PATH\Saved_Simulation_data')); % Saved simulation data  
 
% ASSIGN PATHS TO FUNCTIONS AND DATA: WORK MACPRO
path(path,genpath('/Users/s1040865/Dropbox/PhD/Modelling/Programs/Matlab/Working_Folder_April_2018/PATH/functions')); % Function path
path(path,genpath('/Users/s1040865/Dropbox/PhD/Modelling/Programs/Matlab/Working_Folder_April_2018/PATH/data')); % Data path
path(path,genpath('/Users/s1040865/Dropbox/PhD/Modelling/Programs/Matlab/2018/Working_Folder_April_2018/Saved_Simulation_data')); % Saved simulation data

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% GLOBAL SCRIPT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% COUPLED MODEL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% USES MEASURED ONSET FLOW DATA FROM REDAPT AS AN INPUT

% CALCULATES THE UNSTEADY INDUCTION FACTORS WHICH
% ACCOUNT FOR DYNAMIC STALL AND ROTATIONAL AUGMENTATION

% This script determines axial and tangential induction factors by
% calculating the non-linear, rotational, unsteady lift and drag 
% coefficients at each blade section. Look up tables are formed
% with the unsteady values by binning and smoothing them. The simulation
% runs until the induction factors converge.


% The initial conditions are only required when a new dataset is used. 
% The initial conditions determines the induction (quasi-steady) factors
% and the axial and tangential velocities acting on EACH blade. The
% induction factors are detemined using blade 1 only. However, for CP and
% CT data is required for each blade.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% INITIALISATION CALLS
% FOLLOWING CALLS TO PRE-PROCESS DATA
%
% 1: CALL TO PreProcessor1       - Extrapolate static aerofoil data
%                                  to deep stall region.
%                                - Apply rotational augmentation
%                                  correction
%                                - Compute the point of trailing edge separation
% 2: CALL TO InitialConditions   - Calculate velocities and induction factors for first rotation (QUASI-STEADY)
% 3: CALL TO MeanInduction       - Time average and clean induction factors
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BLADE LOADS
% FOLLOWING CALLS MADE 
%
% 2:  CALL TO wag                 - Determine unsteady linear Cl for each blade(2D array)
% 3:  CALL TO DS_3D               - Determine 3D unsteady non-linear Cl and Cd  for each blade (2D array)
% 4:  CALL TO UnstCD              - Determine 3D unsteady non-linear Cd and for each blade (2D array)
% 5:  CALL TO UNSTEADY_POLARS     - Bin and average unsteady coefficients and compile look-up table
% 6:  CALL TO VitExt              - Extrapolate look-up table (2D array)
% 7:  CALL TO BEM_TIME_UNSTEADY   - Compute induction factors at each time step through period of revolution
% 8:: CALL TO MeanInduction       - Time average and clean the unsteady induction factors
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear, clc, close all

        %% inputs

        % Operating conditions 
        
        % TSR=3.5;                   % tip speed ratio7
        % Pitch = 1.2;               % pitch angle (deg)

        % TSR=4.0;                   % tip speed ratio
        % Pitch = 0.2;              % pitch angle (deg)

        TSR=4.5;                   % tip speed ratio
        Pitch = 0.1;               % pitch angle (deg) 
        
        U0=2.77;                    % streamwise current (m/s)
        ZTb=18;                     % distance from bed to the hub centre (m)


        %%%%%%%%%%%%%%%%%%%% Turbine specifications %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        file_turb ='TGL_TURBINE';
        load(file_turb)
        % THIS IS THE FULL SCALE TGL BLADE GIVEN BY GRETTON
        Blades =3;
        pitch=deg2rad(Pitch); % operational pitch applied (degree)
        % Discretise blade
        NBsec = 100; % number of blade sections
        r=linspace(rad(1),rad(end),NBsec);
        % Interpolate twist and chord
        B=interp1(rad,B,r,'PCHIP')+pitch; c=interp1(rad,c,r,'PCHIP');

        R=(r(end));                 % radius of blade
        omega = abs(U0*TSR/R);      % rotational speed of blades (rad/s)
        Tr = (2*pi)/omega;          % period of rotation (s)

        file_flow = 'ReDAPT_FlowSample'; % ReDAPT flow data
        load(file_flow)

        dt=Tr/72; % dt= 5 degrees

        %% PREPROCESSOR
        % ROTATONAL AUGMENTATION / STALL DELAY / SEPARATION POINT
        
        file_foil = 'S814_static_data';
        load(file_foil)
        
        [Values_360, Values_360r] = PreProcessor1(aoa,Cl_2d,Cd_2d,Cn_2d,Clin,LinRange,B,r,c,az);
        
        file_ds ='S814_DS_parameters';
        %% INITIAL CONDITIONS  
        
        % !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!%
        % !!!!! ***** UNCOMMENT BELOW WHEN CHANGING FLOW OR TSR ***** !!!!%
        % !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!%

%          % calculate velocities and induction factors
%         [U_axial,U_theta,a,a_p,t,steps,Tr_steps]=InitialConditions(data,TSR,U0,ZTb,Tr,r,B,c,dt,Values_360r);
% 
%         % clean and mean induction factors
%         [A_axial,A_tangential] = MeanInduction(a(:,1:steps),a_p(:,1:steps));
%         
%         save('Initial_conditions_TSR_4p5','U_axial','U_theta','a','A_axial','a_p','A_tangential','t','steps','Tr_steps')
%         
%         "Initial conditions completed"
        
        
        file_init = 'Initial_conditions_TSR_4p5';
        load(file_init)

         

         % starting values
         Err=1E+3;
         Ep=1E-6;
         n=1;
         j=0;
            
         % Preallocation
            
         Axial_induction=ones(length(r),length(t)-(steps));
         Tangential_induction=ones(length(r),length(t)-(steps));
            
         AoA=ones(length(r),steps,Blades);
         Cl_DS_3d=ones(length(r),steps,Blades);
         Cd_DS_3d=ones(length(r),steps,Blades);
            
            
        n1=1;            % start position
        n2=steps;        % end position


for i=1:length(t)-(steps) % every time step but the first full rotation counts as one time step


        %% START ITERATION

while Err > Ep

        j=1+j;
    
        if j>n*5 % if no convergence after 5 iterations relax the convergence parameter 
            Ep=Ep*10;
            n=n+1;
        end
    
        % Update induction factors from previous iteration
        A_Axial=A_axial;
        A_Tangential=A_tangential;
        
       %% DETERMINE AOA
       
       % slice the velocity components to be analysed
       Ua=U_axial(:,n1:n2,:);
       Ut=U_theta(:,n1:n2,:);
       
       parfor ii=1:Blades
        
        % Angle of attack
        AoA(:,:,ii) = 90-atan2d(Ut(:,:,ii).*(1+A_tangential),Ua(:,:,ii).*(1-A_axial))-(rad2deg(B)');

        %% DETERMINE UNSTEADY LOADS
    
        % CALL INDICIAL SOLUTION
        
        [Cl_US, Cl_c, Cl_nc, Ds, aE] = wag(c,dt,U0,deg2rad(AoA(:,:,ii)),az,Clin);
        
        % CALL DYNAMIC STALL SOLUTION
        % ROTATIONAL AUGMENTATION SOLUTION
        [~, ~, Cl_DS_3d(:,:,ii), Dvis, Cd_Ind ,~ ,~ ,~] = DS_3D(B,c,Values_360r,r,Cl_US,Cl_c,Cl_nc,Ds,aE,deg2rad(AoA(:,:,ii)),file_ds);
        
        % DRAG
        
        [Cd_DS_3D(:,:,ii)] = UnstCD(Dvis,Cd_Ind,Values_360,Values_360r,aE,r,Cd0);
       end
     
        % Avoid numerical issues with end nodes where flow tends to zero
        AoA(1,:,:)=AoA(2,:,:);
        AoA(100,:,:)=AoA(99,:,:);
        
        Cl_DS_3d(1,:,:)=Cl_DS_3d(2,:,:);
        Cl_DS_3d(100,:,:)=Cl_DS_3d(99,:,:);
        
        Cd_DS_3d(1,:,:)=Cd_DS_3d(2,:,:);
        Cd_DS_3d(100,:,:)=Cd_DS_3d(99,:,:);
        
       
        % CONCATENATE / RESHAPE
        Aoa=reshape(AoA,length(r),[],1);
        Cl_DS=reshape(Cl_DS_3d,length(r),[],1);
        Cd_DS=reshape(Cd_DS_3d,length(r),[],1);
        % Save values for UNSTEADY_POLARS
        ValuesIn.AoA_In=Aoa;
        ValuesIn.Cl_In=Cl_DS;
        ValuesIn.Cd_In=Cd_DS;


        %% MAKE UNSTEADY POLARS

        % bin unsteady data, take mean of bin, clean and apply smoothing spline
        bins=50; % number of AoA bins (more bins = more NaNs!)
        AR=10;
        ValuesOut = UNSTEADY_POLARS(ValuesIn,bins); % this function makes unsteady aoa vs CL, CD
        
        for k =1:length(r)
        % Extrapolate unsteady coefficients through 360 degrees  (-180 <-> 180)
        [Values_360u.Alpha, Values_360u.Cl(:,k), Values_360u.Cd(:,k),~] = VitExt(ValuesOut.aoa(k,:),ValuesOut.Cl(k,:),ValuesOut.Cd(k,:));
        end

        %% CALCULATE INDUCTION FACTORS USING UNSTEADY POLARS
        
        parfor kk =1:steps
        TSR_unsteady=U_theta(:,n1+kk,1)./U_axial(:,n1+kk,1);
        [a(:,kk),a_p(:,kk)] = BEM_TIME_UNSTEADY(U0,TSR,TSR_unsteady,Blades,r,c,B,Values_360u);
        end
        
        
        % Set end conditions
        a(1,:)=0.990;
        a(100,:)=0.990;
        a_p(1,:)=0.001;
        a_p(100,:)=0.001;
        
         % clean and mean induction factors
        [A_axial,A_tangential] = MeanInduction(a,a_p);
        Err=(sum((A_axial-A_Axial).^2)); % Absolute

               
end

        % display converged iteration number and error
        i
        Err


        % store the induction factors
        Axial_induction(:,i)=A_axial;
        Tangential_induction(:,i)=A_tangential;

        % update index counters for next rotation

        n1=n1+1;  % update start position
        n2=n2+1;  % update end position

        % reset values

        Err=1E+3;
        Ep=1E-6;
        n=1;
        j=0;


end

% SAVE THE INDUCTION FACTORS
save('ReDAPT_Unsteady_TSR_4p5','Axial_induction','Tangential_induction')



