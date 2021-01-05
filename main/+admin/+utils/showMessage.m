function [btn, tf] = showMessage(text, title, varargin)
if nargin < 2
  title = '';
end
presenter = appbox.MessagePresenter(text, title, varargin{:});
presenter.goWaitStop();
results = presenter.result;
if ~isempty(results)
  btn = results{1};
  tf = results{2};
else
  btn = [];
  tf = [];
end
end