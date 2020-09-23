function colormatrix = getColorShades(nshades,ncolors,interpolate)
% GETSHADES Get a color array nshades x (rgb) x ncolors
if nargin < 3
  interpolate = false;
end
if nargin < 2
  ncolors = 1;
end

assert(nshades > 0);

cnames = [ ...
  "2f5560"; ... % dark-slate-grayff
  "335c67"; ... % deep-space-sparkleff
  "adced7"; ... % light-blueff
  ...
  "8d5e16"; ... % golden-brownff
  "dd962c"; ... % harvest-goldff
  "f1d3a7"; ... % deep-champagneff
  ...
  "a32c00"; ... % rufousff
  "e53d00"; ... % flameff
  "ffb499"; ... % melonff
  ...
  "687e25"; ... % avocadoff
  "87a330"; ... % citronff
  "dae8b0"; ... % pale-spring-budff
  ...
  "83008f"; ... % mardi-grasff
  "f15cff"; ... % heliotropeff
  "f8adff"; ... % mauveff
  ...
  "4e2d43"; ... % dark-byzantiumff
  "1c1018"; ... % xiketicff
  "dabed1"; ... % thistleff
  ...
  "173c64"; ... % indigo-dyeff
  "5997d9"; ... % blue-grayff
  "accbec"; ... % baby-blue-eyesff
  ...
  "6d0d11"; ... % rosewoodff
  "540b0e"; ... % rosewoodff
  "f6b7b9"; ... % spanish-pinkff
  ...
  "105638"; ... % castleton-greenff
  "75e6b5"; ... % medium-aquamarineff
  "baf2da"  ... % aero-blueff
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