function [grad_z,grad_x,k,sws_matrix] = phase_estimator_QR_bigmat(u, w_kernel,f_v,dinf,og_size,constant,pars)
% function [grad_z,grad_x,k,sws_matrix] = phase_estimator_QR_bigmat(u, w_kernel,f_v,dinf,og_size,constant,pars)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function that yields the shear wave speed of a region with the 
% phase gradient method with QR solver MATLAB first version. 
% 
% Inputs:  
%          u           : 2D region of interest to evaluate (previously mirror padding)
%          w_kernel    : vector with the size of the window kernel
%          f_v         : vibration frequency
%          dinf        : structure that contains the spatial resolutions
%          og_size     : vector containing the original size of the data
%          lambda      : regularization coefficient

% Outputs: 
%          grad_z       : Gradient matrix for the axial direction
%          grad_x       : Gradient matrix for the lateral direction
%          k            : Total Wavenumber matrix 
%          sws_matrix   : Shear wave speed matrix 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    
    lambda = pars.lambda;
    tau = pars.tau;
    maxIter = pars.maxIter;
    tol = pars.tol;
    numberEstimators = 1;
    stableIter = pars.stableIter;


    res_z = dinf.dz; % Axial resolution
    res_x = dinf.dx; % Lateral resolution
    
     % Axis of the kernels
    z_axis = linspace(-(w_kernel(1)-1)/2,(w_kernel(1)-1)/2,w_kernel(1))*res_z; 
    x_axis = linspace(-(w_kernel(1)-1)/2,(w_kernel(1)-1)/2,w_kernel(2))*res_x; 
    
    %% Initializing vectors and matrixes
    grad_z = zeros(og_size); 
    grad_x = grad_z; % matrixes containing the estimated wavenumber along each direction
    
    angle_u = angle(u);
    [M, N] = size(angle_u);
    %angle_u_unwrp = unwrap(angle_u, [], direction);
    %angle_u_unwrp = unwrap(angle_u, [], 2);   
    
    [X, Z] = meshgrid(x_axis,z_axis);
    A_small = [X(:) Z(:) ones(length(x_axis)*length(z_axis),1)]; 
    [numRows, numCols] = size(A_small); % [ww, 3]
%     b_small = zeros( size(w_kernel(1), w_kernel(2)) );

    % Better pre-allocation v2.0
%    501−15+1 = 487.^2, if not mirror padding is applieds
    st = 1;
    numSubMatrices = ceil(M/st)*ceil(N/st); 
%     Az_large = sparse(numSubMatrices*numRows, numSubMatrices*numCols);

    Az_large = kron(speye(numSubMatrices), A_small);
    bz_large = zeros(numSubMatrices*numRows, 1); 
    Ax_large = Az_large;
    bx_large = bz_large;

    % For concatenation v1.0
%     A_large = [];
%     b_large = [];
	     
    angle_z = unwrap(angle_u,[],1);
    angle_x = unwrap(angle_u,[],2);
    cont_kernel = 1; 
    for ii = 1:st:og_size(1)

        for jj = 1:st:og_size(2) %% for faster computing pararell toolbox
            
            area_z = angle_z(ii: ii+w_kernel(1)-1,jj:jj+w_kernel(2)-1); % Window kernel
            bz_small = area_z(:);
            area_x = angle_x(ii: ii+w_kernel(1)-1,jj:jj+w_kernel(2)-1); % Window kernel
            bx_small = area_x(:);

            %%%%%%%%%%%% BETTER EFFICIENCY v2.0 %%%%%%%%%%%%
            rowStart = (cont_kernel-1)*numRows + 1; % size ww
%             colStart = (cont_kernel-1)*numCols + 1; % size 3

%             Az_large(rowStart:rowStart+numRows-1, colStart:colStart+numCols-1) = A_small;
            bz_large(rowStart:rowStart+numRows-1) = bz_small;
            bx_large(rowStart:rowStart+numRows-1) = bx_small;
            
            %%%%%%%%%%%% BETTER EFFICIENT v2.0 %%%%%%%%%%%%

%             %%%%%%%%%%%% NOT SO EFFICIENT v1.0 %%%%%%%%%%%%
%             if (ii==1 && jj==1) % first window
%                 A_large = A_small;
%                 b_large = b_small; % concatenate b
%                 % concatenate A_small
%             else
%                 A_large = [A_large               sparse(size(A_large, 1), size(A_small, 2)); 
%                      sparse(size(A_small, 1), size(A_large, 2)), A_small];
%                 b_large = [b_large; b_small];
%             end
%             %%%%%%%%%%%% NOT SO EFFICIENT v1.0 %%%%%%%%%%%%

            cont_kernel = cont_kernel + 1;
        end
    end

    disp(cont_kernel);
    %%%%% FOR x %%%%%
    results_x = Ax_large\bx_large;  
    res3D_x = reshape(results_x, [M, N, 3]); clear results_x
%     kx_x = res3D_x(:,:,1); kz_x = res3D_x(:,:,2); 
    %%%%% FOR z %%%%%
    results_z = Az_large\bz_large;  
    res3D_z = reshape(results_z, [M, N, 3]); clear results_z
%     kx_z = res3D_z(:,:,1); kz_z = res3D_z(:,:,2); 
    
    grad_x = res3D_x(:,:,1); grad_z = res3D_z(:,:,2);
    phase_grad_2 = grad_x.^2 + grad_z.^2;
    
    % ----- MedFilt  ----
    med_wind = floor (2.5/f_v/dinf.dx)*2+1; %the median window contains at least a wavelenght
    k2_med = medfilt2(phase_grad_2,[med_wind med_wind],'symmetric')/constant;
    k = sqrt(k2_med);
    % --------------------
    sws_matrix = (2*pi*f_v)./k;   
end