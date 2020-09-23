function fMat = doDigitalFilter(dMat, fs, nBaselinePts, type, freqs, ord)
% DODIGITALFILTER performs a butterworth digital forward->reverse filt
% (filtfilt) on the columns of an inupt matrix.

% validate
if nargin < 2, error('Sampling frequency required!'); end
if nargin < 3, nBaselinePts = size(dMat,1); end
if nargin < 4, type = 'low'; end
if nargin < 5, freqs = 30; end
if nargin < 6, ord = 4; end  


type = validatestring(type,{'low','bandpass','high'});
switch type
  case 'low'
    flt = 2*freqs(1);
  case 'bandpass'
    if numel(freqs) ~= 2
      error('Frequency must be 2 element vector for type = "bandpass".'); 
    end
    flt = sort(2.*freqs);
  case 'high'
    flt = 2*max(freqs);
end

try
  ButterParam('save');
catch e
  fprintf(2,'ButterParam.mat not accessible: "%s"\n',e.message);
end

% determine columns means
mu = mean(dMat(1:nBaselinePts,:),1,'omitnan');

% zero mean the data
fMat = dMat-mu;

% replace nans with determined values
[rowNans,colNans] = find(isnan(dMat));
for rc = 1:length(rowNans)
  fMat(rowNans(rc),colNans(rc)) = 0;
end

% build filter
[b,a] = ButterParam(ord,flt./fs,type);

% perform filter
fMat = FiltFiltM(b,a, fMat);

% add Mu back in
fMat = fMat + mu;

% replace nan positions with nan
for rc = 1:length(rowNans)
  fMat(rowNans(rc),colNans(rc)) = nan;
end

end

