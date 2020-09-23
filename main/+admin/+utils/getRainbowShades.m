function colormatrix = getRainbowShades(nshades,ncolors,interpolate)
% GETSHADES Get a color array nshades x (rgb) x ncolors
if nargin < 3
  interpolate = false;
end
if nargin < 2
  ncolors = 1;
end

assert(nshades > 0);

cnames = [ ...
  "770406"; ... % barn-redff
  "f9393c"; ... % tart-orangeff
  "fc9c9e"; ... % salmon-pinkff
  ...
  "602506"; ... % seal-brownff
  "f26418"; ... % safety-orange-blaze-orangeff
  "f9be9f"; ... % peach-crayolaff
  ...
  "623804"; ... % pullman-brown-ups-brownff
  "f89012"; ... % yellow-orange-color-wheelff
  "fbc888"; ... % gold-crayolaff
  ...
  "765404"; ... % field-drabff
  "f7b926"; ... % selective-yellowff
  "fad275"; ... % orange-yellow-crayolaff
  ...
  "263819"; ... % kombu-greenff
  "7eb356"; ... % bud-greenff
  "b4d39c"; ... % celadonff
  ...
  "1d493c"; ... % brunswick-greenff
  "43aa8b"; ... % zompff
  "99d6c4"; ... % middle-blue-greenff
  ...
  "263440"; ... % gunmetalff
  "54728c"; ... % queen-blueff
  "b3c3d1"  ... % beau-blueff
  ];

nMax = length(cnames)/3;
interpolate  = interpolate && (ncolors > nMax);

% rgbvalues from hex
cvals = zeros(numel(cnames),3);
for i = 1:numel(cnames)
  cvals(i,:) = sscanf(cnames(i),'%2x%2x%2x',[1 3])/255;
end

% convert to put columns as rows as rgb, cols and colors and dim 3 as shades for
% interp if needed
cvals = permute(reshape(cvals',3,3,[]),[3,1,2]);

if interpolate
  % interpolate between colors get cvals(:,:,3) to ncolors size
  newVals = zeros(ncolors,3,3);
  [x,y] = meshgrid(1:3,1:nMax);
  [ix,iy] = meshgrid(1:3,linspace(1,nMax,ncolors));
  for d = 1:3
    newVals(:,:,d) = interp2( ...
      x, y, ...
      cvals(:,:,d), ...
      ix,iy, ...
      'spline' ...
      );
  end
  % clip anything that exceeds color bounds
  newVals(newVals > 1) = 1;
  newVals(newVals < 0) = 0;
  newVals(isnan(newVals)) = 1;
  cvals = newVals;
end

% permute again to get the colors in 3 dims and
cvals = permute(cvals,[3,2,1]);

% build the final color matrix
colormatrix = zeros(nshades,3,ncolors);
for c = 1:ncolors
  cIdx = mod(c-1,nMax)+1;
  if nshades <= 3
    colormatrix(:,:,c) = cvals(1:nshades,:,cIdx);
  else
    thismat = cvals(:,:,cIdx);
    h = size(thismat,1);
    colormatrix(:,:,c) = interp1( ...
      1:h, ...
      thismat, ...
      linspace(1,h,nshades), ...
      'linear' ...
      );
    
  end
end

colormatrix(colormatrix > 1) = 1;
colormatrix(colormatrix < 0) = 0;
end