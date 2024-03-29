% ************************************************************************%
%                                                                         %
%                   Relative output regulation of                         %
%                   space manipulators on Lie groups                      %
%                                                                         %
%                                                                         %
% Developed by:     Borna Monazzah Moghaddam                              %
%                   Autonomous Space Robotics and Mechatronics Laboratory %
% Supervised by:    Robin Chhabra,                                        %
%                   Carleton University, Ottawa, Canada.                  %
%                                                                         %
% Initiated: 2022 August                                                  %
%                                                                         %
% Edited:                                                                 %
% ************************************************************************%

clc
close all
clear


% -------------------------------------------- Import toolboxes

% Selfmade classes


% ******************* Initiate Constants and Dimensions **************** %%

% --------------- Initiate the robot model properties and class

% [base, link1, link2, ee]= initiate_robot();

% __________ Create Robot structure __________ %

% prompt = 'The robot info file address:';
% dlgtitle = 'Create the Robot';
% dims = [1 70];
% definput = {'robot.csv'};
% address = inputdlg(prompt,dlgtitle,dims,definput);
% 
% robot=create_robot(address);

% -------------------------------------------------- Simulation

% Initial definitions
% ts = 0.0;
% tf = 1.0;
% dt = 0.01;

% bodies = [base, link1, link2, ee];

% Prepare properties in workspace to be fed to simulink model

n=7; %number of joints in the manipulator

rho=transpose([0 0 2.5; 0 0 2.5; 0 0 2.5;... % shoulder ball joint
            0 0 7; ... %elbow revolute joint3
            0 0 11.5; 0 0 11.5; 0 0 11.5;] ... %wrist ball joint
            ); %m %position of joints in initial configuration
w=transpose([0 0 1; 0 1 0; 1 0 0; ... % shoulder ball joint
            1 0 0;... %elbow 
            0 0 1; 0 1 0; 1 0 0; ... %wrist joint
            ]); %vector of rotation of each joint in inertial frame in initial pose

% Initiate Iota the inclusion map of the base
iota0=eye(6,6);

% form the overall twist matrix
Xi_m_matrix=zeros(6*n,n);
Xi_m_temp=zeros(6,n);
for i=1:n
    v(1:3,i)=-cross(w(1:3,i),rho(1:3,i));
    Xi_m_temp(1:6,i)=[v(1:3,i);w(1:3,i)];
    Xi_m_matrix(6*(i-1)+1:6*(i-1)+6,i)=[v(1:3,i);w(1:3,i)];
end

Xi_m(1,:,:)=Xi_m_temp;

% Set the initial poses relative to spacecraft
R=zeros(3,3,n);
g_bar=zeros(4,4,n);
for i=1:n
    R(1:3,1:3,i)=eye(3);
    g_bar(1:4,1:4,i)=[R(1:3,1:3,i) rho(1:3,i); 0 0 0 1];
end

g_cm=zeros(4,4,n);
% Set the initial poses of CoM of bodies in joint frames
for i=1:n
    g_cm(1:4,1:4,i)=[eye(3) zeros(3,1); 0 0 0 1];
end

%Xi_m=0;
mu=zeros(6,1)';
mu_t=zeros(6,1)';

m0=100;%kg
mm=[2 2 0]; % link1, link2, wrist masses

% Inertia of arm
Im=zeros(3,3,n);
for i=1:n
    Im(1:3,1:3,i)=eye(3);
end

% % form the collected diagonal mass matrix in joint frames
diagM=zeros(6*n+6);
for i=1:n+1
    diagM(i*6+1:i*6+6,i*6+1:i*6+6)=inv(transpose(Adjoint(g_cm(1:4,1:4,i))))...
        *[mm(i).*eye(3) zeros(3); zeros(3) Im(1:3,1:3,i)]...
        *inv(Adjoint(g_cm(1:4,1:4,i)));
end
% 
% % form mass matrix in the spacecraft frame
for i=1:n+1
    m_frak(1:6,1:6,i)=inv(transpose(Adjoint(g_bar(1:4,1:4,i))))*(diagM(i*6+1:i*6+6,i*6+1:i*6+6))*inv(Adjoint(g_bar(1:4,1:4,i)));
end

% ************** Initiate forces

f_0=[0;0;0;0;0;0];
f_m=[0;0;0;0;0;0;0];
f_e=[0;0;0;0;0;0];

% ************** Initiate states

q_m=[0;0;0;0;0;0;0];
q_dot_m=[0;0;0;0;0;0;0];
P=[0;0;0;0;0;0];
V_I0=[0;0;0;0;0;0];

% *************************** Set Target parameters

w_t=[0 0.5 0.5];
mt=100;
M_t=[eye(3)*mt zeros(3); zeros(3) eye(3)*416.667];

% *************************** Set Controller parameters

K_p=eye(6);
K_d=eye(6);
K_i=eye(6);


%% ********************** Simulink Controller

sim('ACC_Controller.slx') 

%% ************* Symbolic Spacecraft-Manipulator System *********** %%

% Simulation
% robot.simulate(ts=ts, tf=tf, dt=dt, rec=rec);

Jacobian=Jacobian(robot,q);

Ad_g0I=simplify(Adjoint(robot.vehicle.g));


% Masses
robot.vehicle.M_frak=[robot.vehicle.mass zeros(3); zeros(3) robot.vehicle.inertia];
for j=1 : robot.n
    robot.links(j).M_frak=transpose(inv(Adjoint(robot.links(j).g_cm0)))*[robot.links(j).mass zeros(3); zeros(3) robot.links(j).inertia]*inv(Adjoint(robot.links(j).g_cm0));
    robot.links(j).M_frak=simplify(robot.links(j).M_frak);
end

% for loop
for j=1:robot.n
    Xi_m((j-1)*6+1:j*6,j)=robot.joints(j).xi;%[robot.joints(1).xi zeros(6,1);zeros(6,1) robot.joints(2).xi];
end
Xi_m=Xi_m(1:robot.n*6,1:robot.n);


Ad_g10=simplify(Adjoint(g(robot.joints(1).xi,-q1)));
Ad_g21=simplify(Adjoint(g(robot.joints(2).xi,-q2)));
Ad_g20=Ad_g21*Ad_g10;

[Lm0,Lm]=form_L(robot,q);


Lm02=[Ad_g10;Ad_g20];
Lm=[eye(6) zeros(6); Ad_g21 eye(6)];

% Calculate the Mass matrix

for j=1:robot.n
    diagM((j-1)*6+1:j*6,(j-1)*6+1:j*6)=robot.links(j).M_frak;
end

M0=simplify(transpose(robot.vehicle.iota_0)*robot.vehicle.M_frak*robot.vehicle.iota_0...
    +transpose(robot.vehicle.iota_0)*transpose(Lm0)*diagM*Lm0*robot.vehicle.iota_0);

M0m=simplify(transpose(robot.vehicle.iota_0)*transpose(Lm0)*diagM*Lm*Xi_m);

Mm=simplify(transpose(Xi_m)*transpose(Lm)*diagM*Lm*Xi_m);


% Calculate the connection

A=simplify(inv(M0)*M0m);

% Find generalized Mas Matrix

M_hat=Mm-transpose(A)*M0*A;

% Find generalized Momentum

Omega=V_curly+A*qdot;
P=M0*Omega;

% Calculate ad*
ad_V_curly=lie_alg(V,robot.vehicle.iota_0);

% Calculate P_dot
P_dot=ad_V_curly*P;

%

%% ************* Propagate the Spacecraft-Manipulator System *********** %%

% __________ Calculate the tranformation matrix __________ %
% _ for each joint and the corresponding CG of the body __ %
% for i=1:robot.n
%     % Initial g including Rotation and Translation caused by joint i
%     robot.links(i).T = g_Matrix(0,robot.joints(i).T(1:3,4),xi(:,:,i));
%     % Initial Homogeneous transformation of the joints
%     if i~=1
%         robot.joints(i).T=[eye(3),robot.joints(i-1).T(1:3,4)/2;zeros(1,3),1];
%     else
%         robot.joints(i).T=[eye(3),r0;zeros(1,3),1];
%     end
% end

time_step=0.01;
tspan=10;
step=0;

y=zeros(2*(b+n),tspan/time_step);
y(1:2*(n+b),1)=[q;qdot_0];
% qm=[0;0]; 
tt=[0:time_step:tspan];

for time=0:time_step:tspan
    step=step+1;
    
    % extract V_0 and q_m and their derivatives
    P=y(1:b,step); %V_0I_curly
    qm=y(b+1:b+n,step);
    P_dot=y(b+n+1:2*b+n,step);
    qm_dot=y(2*b+n+1:2*(b+n),step);
%     R0=Rotation(wb4,qb(4))*Rotation(wb5,qb(5))*Rotation(wb6,qb(6));
%     r0=qb(1:3);
    g10=g(robot.joints(1).xi,q(1));
    g21=g(robot.joints(2).xi,q(2));
    % **************************** Kinematics *************************** %
    
    % __________ Kinematics __________ %
    [Rij,R_cm,rJ,rL,e,g]=Kinematics(R0,r0,qm,robot,xi);
    %End-Effector
    g_n=[Rij(1:3,1:3,end),rJ(1:3,end);zeros(1,3),1]*[eye(3),[0;L2;0];zeros(1,3),1];
    ree(:,step)=g_n(4,1:3);
    % __________ Differential kinematics __________ %
    [t0,tm,Tij,Ti0,P0,pm]=DifferentialKinematics(R0,r0,rL,e,g,qb_dot,qm_dot,robot);

    %End-effector Jacobian
    [J0ee, Jmee]=Jacob(g_n(1:3,4),r0,rL,P0,pm,robot.n,robot);

    % __________ Inertia Matrices __________ %
    % The conjugate mapping and unification of the frame of representation of
    % inertia and mass matrices
    % Inertias in inertial frames
    [I0,Im]=I_I(R0,R_cm,robot);
    % Mass matrix
    [M0_tilde,Mm_tilde]=Mass_Matrix(I0,Im,Tij,Ti0,robot);


    %Generalized Inertia matrix
    [H0, H0m, Hm] = Hgen(M0_tilde,Mm_tilde,Tij,Ti0,P0,pm,robot);
    H=[H0,H0m;H0m',Hm];
    % C matrix (Very uncertain, therefor not used)
    [C0, C0m, Cm0, Cm] = Cgen(t0,tm,I0,Im,M0_tilde,Mm_tilde,Tij,Ti0,P0,pm,robot);
    C=[C0,C0m;Cm0,Cm];
    
    % ***************************** Dynamics **************************** %

    % __________ Forward Dynamics __________ %

    %External forces (includes gravity and assumes z is the vertical direction)
    F0=[0;0;0;0;0;-robot.spacecraft.mass*gg]; % in generalized coord
    Fm=[zeros(5,robot.n_q); -robot.links(1).mass*gg,-robot.links(2).mass*gg];

    %Joint torques (not external torques assumed)
    tauq0=zeros(6,1);
%     tauqm=zeros(robot.n_q,1);
    tauqm=[0;0];

    %Forward Dynamics (get the velocities of generalized coordinates)
    [u0dot_FD,umdot_FD] = Forward_Dynamics(tauq0,tauqm,F0,Fm,t0,tm,P0,pm,I0,Im,Tij,Ti0,qb_dot_0,qm_dot_0,robot);
    
      % Update generalized coordinates
%     qb_dot=u0dot_FD; % Initial Base-spacecraft linear and angular velocities
%     qm_dot=umdot_FD; % Initial Joint velocities [Rad]
    
%     qb=qb+qb_dot*time_step;
%     qm=qm+qm_dot*time_step;
%     q=[qb;qm]

    dy=y(n+7:2*n+12,step);
    ddy=-inv(H)*C*y(n+7:2*n+12,step)+inv(H)*[u0dot_FD;umdot_FD];
    
    
    y(1:n+6,step+1)=y(1:n+6,step)+dy*time_step;
    y(n+7:2*n+12,step+1)=y(n+7:2*n+12,step)+ddy*time_step;
    
%     opts = odeset('RelTol',1e-2,'AbsTol',1e-4);
%     [t,y] = ode45(Dynamics,tspan,y0,opts);
    Momentum(1:n+6,step)=H*y(n+7:2*n+12,step);
end


%% ----------------------------------- Results and Visualisation

figure(1)
% plot3(y(1,:),y(2,:),y(3,:))
plot(tt(1:100),y(1,1:100))
hold on
plot(tt(1:100),y(2,1:100))
plot(tt(1:100),y(3,1:100))
legend x y z

figure(2)
plot(tt(1:100),y(4,1:100))
hold on
plot(tt(1:100),y(5,1:100))
plot(tt(1:100),y(6,1:100))
legend \theta_{b1} \theta_{b2} \theta_{b3}

figure(3)
plot(tt(1:100),y(7,1:100))
hold on
plot(tt(1:100),y(8,1:100))
legend \theta_1 \theta_2

figure(4)
plot3(y(1,1:100),y(2,1:100),y(3,1:100))
legend r_{b}
grid on

figure(5)
% plot3(y(1,:),y(2,:),y(3,:))
plot(tt(1:100),y(9,1:100))
hold on
plot(tt(1:100),y(10,1:100))
plot(tt(1:100),y(11,1:100))
legend v_x v_y v_z

figure(6)
plot(tt(1:100),y(12,1:100))
hold on
plot(tt(1:100),y(13,1:100))
plot(tt(1:100),y(14,1:100))
legend \omega_{b1} \omega_{b2} \omega_{b3}

figure(7)
plot(tt(1:100),y(15,1:100))
hold on
plot(tt(1:100),y(16,1:100))
legend \omega_1 \omega_2

