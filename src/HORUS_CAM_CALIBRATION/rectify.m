function [u v rectimg]=rectify(img,H,K,D,roi,z,resolution,paint)
%
% [u v rectimg]=rectify(img,H,K,D,roi,z,resolution,paint)
% This function rectifies a given image using the Pinhole model matrix or
% the DLT of the camera. It does not take into account the distortion
% effects of the lenses. After defining the value of Z, the user needs to
% choose 4 points on the image that define the rectification area. The
% rectification process is carried out as presented in P�rez (2009) and
% P�rez et al (2011).
% Inputs:
%     img: Image to be rectified in a multidimensional array of Matlab as
%     obtained using the function imread of Matlab. The image can be
%     grayscale or RGB.
%     H: Pinhole matrix H=K[R t]  or DLT as presented in P�rez (2009) and
%     P�rez et al (2010).
%     K: 3x3 upper triangular matrix with the intrinsec parameters of the
%     camera model used to correct the lens distortion effect, if no
%     distortion is going to be corrected, matrix  K may be an empty array.
%     D: 1x2 matrix with the radial distortion parameters of the camera
%     model, [k1 k2]. This parameters are used to correct the distortion
%     effects in the image and, therefore, if there is no distortion to
%     correct then D might be an empty array.
%     roi: matrix nx2 (n>=3) with the coordinates (u,v) of the point that
%     define the polygon of the interest area.
%     z: value of the Z coordinate where the interest area is assumed to be
%     located. Depending of the units used for the GCPs its value may be
%     [mm], [cm] or [m].
%     resolution: Desired resolution of the resulting rectified image,
%     depending of the units used for the GCPs its value may be [mm/pix],
%     [cm/pix] or [m/pix].
%     paint: control parameter to plot the results. 1 to plot the
%     rectified image, 0 to rectify without plotting.
%  Outputs:
%     u: coordenadas U of the rectified area, used as input in the function
%     plot_resolution
%     v: coordenadas V of the rectified area, used as input in the function
%     plot_resolution
%     rectimg: Rectified image, can be displayed directly using imshow or
%     imagesc, but there are no grid lines to localize points in XY. If you
%     want to plot the rectified image with gridlines and coordinates
%     values, use the function plot_rectified.
%
%   Developed by Juan camilo P�rez Mu�oz (2011) for the HORUS project.
%
% References:
%   P�REZ, J.  M.Sc. Thesis, Optimizaci�n No Lineal y Calibraci�n de
%   C�maras Fotogr�ficas. Facultad de Ciencias, Universidad Nacional de
%   Colombia, Sede Medell�n. (2009). Available online in
%   http://www.bdigital.unal.edu.co/3516/
%   P�REZ, J., ORTIZ, C., OSORIO, A., MEJ�A, C., MEDINA, R. "CAMERA
%   CALIBRATION USING THE LEVENBERG-MARQUADT METHOD AND ITS ENVIROMENTAL
%   MONITORING APLICATIONS". (2011) To be published.
%


%% Rectification process
if isempty(K)||isempty(D)
    IDDist=0;
else
    IDDist=1;
end

if IDDist==1
    for i=1:size(roi,1)
        [u(i,1) v(i,1)]=undistort(K,D,roi(i,:));
    end
else
    u=roi(:,1);
    v=roi(:,2);
end
[X Y Z] = UV2XYZ(H,u,v,z);


newX2 = zeros(4, 3);
newX2(:, 3) = z;

newX2(1, 1) = min(X);
newX2(1, 2) = min(Y);
newX2(2, 1) = min(X);
newX2(2, 2) = max(Y);
newX2(3, 1) = max(X);
newX2(3, 2) = max(Y);
newX2(4, 1) = max(X);
newX2(4, 2) = min(Y);

%Redefining an square on XY containing the back-projections of the ROI
minX = floor(min(newX2(:, 2)));
maxX = floor(max(newX2(:, 2)));
minY = floor(min(newX2(:, 1)));
maxY = floor(max(newX2(:, 1)));

%Defining intervals on X and Y to rectify
deltaX=maxX-minX;
deltaY=maxY-minY;

%Using the desired resolution to calculate the number of pixel needed
gridX=ceil(deltaX/resolution);
gridY=ceil(deltaY/resolution);

%Create a grid to interpolate the intensity values for the new image
try
    [YY,XX]=meshgrid(minX:(maxX-minX)/gridX:maxX,minY:(maxY-minY)/gridY:maxY);
    [i j]=size(XX);
    
    XYZ = ones(i*j,3);
    XYZ(:,3) = z;
    
    XYZ(:,1)=XX(:);
    XYZ(:,2)=YY(:);
catch
    u=[]; v=[]; rectimg=[];
    hmsg=errordlg('There is an error. The selected area is too big or the used model is not accurate','Error');
    waitfor(hmsg);
    return
end

% projecting the points on the rectified image (x,y,z) to the image, to
% calculate the intensity for each one
[U V]=XYZ2UV(H,XYZ);
if IDDist==1
    [U V]=distort(K,D,[U V]);
end

U=ceil(U);
V=ceil(V);

% Selecting just the points that are projected inside the image
BU=(U>0) & (U<=size(img,2));
BV=(V>0) & (V<=size(img,1));

U(U<=0)=1;
U(U>size(img,2))=1;
V(V<=0)=1;
V(V>size(img,1))=1;

RGB=uint8(zeros(j,i,size(img,3)));

if size(img,3)==3
    for band=1:3
        ind=(band-1)*size(img,1)*size(img,2)+(U-1)*size(img,1)+V;
        RGB(:,:,band)=(fliplr(reshape(img(ind).*uint8(BU & BV),[i j])))';
    end
else
    band=1;
    ind=(band-1)*size(img,1)*size(img,2)+(U-1)*size(img,1)+V;
    RGB(:,:,band)=(fliplr(reshape(img(ind).*uint8(BU & BV),[i j])))';
end

%Rectified image
rectimg=RGB;

[u v]=XYZ2UV(H,newX2);
if IDDist==1
    [u v]=distort(K,D,[u v]);
end

%% Plot
if paint
    plot_rectified(rectimg, H, K, D, roi, z)
end

