function [Xdot] = quadOdeFunctionHF(t,X,eaVec,distVec,P)
% quadOdeFunctionHF : Ordinary differential equation function that models
%                     quadrotor dynamics -- high-fidelity version.  For use
%                     with one of Matlab's ODE solvers (e.g., ode45).
%
%
% INPUTS
%
% t ---------- Scalar time input, as required by Matlab's ODE function
%              format.
%
% X ---------- Nx-by-1 quad state, arranged as 
%
%              X = [rI',vI',RBI(1,1),RBI(2,1),...,RBI(2,3),RBI(3,3),...
%                   omegaB',omegaVec']'
%
%              rI = 3x1 position vector in I in meters
%              vI = 3x1 velocity vector wrt I and in I, in meters/sec
%             RBI = 3x3 attitude matrix from I to B frame
%          omegaB = 3x1 angular rate vector of body wrt I, expressed in B
%                   in rad/sec
%        omegaVec = 4x1 vector of rotor angular rates, in rad/sec.
%                   omegaVec(i) is the angular rate of the ith rotor.
%
%    eaVec --- 4x1 vector of voltages applied to motors, in volts.  eaVec(i)
%              is the constant voltage setpoint for the ith rotor.
%
%  distVec --- 3x1 vector of constant disturbance forces acting on the quad's
%              center of mass, expressed in Newtons in I.
%
% P ---------- Structure with the following elements:
%
%    quadParams = Structure containing all relevant parameters for the
%                 quad, as defined in quadParamsScript.m 
%
%     constants = Structure containing constants used in simulation and
%                 control, as defined in constantsScript.m 
%
% OUTPUTS
%
% Xdot ------- Nx-by-1 time derivative of the input vector X
%
%+------------------------------------------------------------------------------+
% References:
%
%
% Author:  
%+==============================================================================+

% Extract quantities from state vector
rI = X(1:3);
vI = X(4:6);
RBI = zeros(3,3);
RBI(:) = X(7:15);
omegaB = X(16:18);
omegaVec = X(19:22);

% Convert voltage applied to rotor angular rates
% Find omega_dot for new state vector
Cm = P.quadParams.cm; 
Tm = P.quadParams.taum;
omegaVecdot = (Cm.*eaVec - omegaVec) ./ Tm;

% Determine forces and torques for each rotor from rotor angular rates.  The
% ith column in FMat is the force vector for the ith rotor, in B.  The ith
% column in NMat is the torque vector for the ith rotor, in B.  Note that
% we negate P.quadParams.omegaRdir because the torque acting on the body is
% in the opposite direction of the angular rate vector for each rotor.
FMat = [zeros(2,4);(P.quadParams.kF.*(omegaVec.^2))'];
NMat = [zeros(2,4);(P.quadParams.kN.*(omegaVec.^2).*(-P.quadParams.omegaRdir)')'];

% Assign some local variables for convenience
mq = P.quadParams.m;
gE = P.constants.g;
Jq = P.quadParams.Jq;
omegaBx = crossProductEquivalent(omegaB);
Cd = P.quadParams.Cd;
Ad = P.quadParams.Ad;
rho = P.constants.rho;
vIMag = norm(vI); 
zI = RBI * [0 0 1]'; % 3x1

% The problem on first iteration
if vIMag == 0
    vIUnitVector = [0 0 0];
else
    vIUnitVector = vI/vIMag; 
end

% Find derivatives of state elements
rIdot = vI;
fd = dot(zI,vIUnitVector)*(vIMag^2); 
da = 0.5*Cd*Ad*rho*fd; 
fDragVec = vIUnitVector*da;
fDrag = [fDragVec(1) fDragVec(2) fDragVec(3)]';
vIdot = ([0;0;-mq*gE] + RBI'*sum(FMat,2) + fDrag)/mq; 
RBIdot = -omegaBx*RBI;
NB = sum(NMat,2);
for ii=1:4
  NB = NB + cross(P.quadParams.rotor_loc(:,ii),FMat(:,ii));
end
omegaBdot = inv(Jq)*(NB - omegaBx*Jq*omegaB);

% Load the output vector
Xdot = [rIdot;vIdot;RBIdot(:);omegaBdot;omegaVecdot];
