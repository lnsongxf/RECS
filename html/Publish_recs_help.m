function Publish_recs_help
% PUBLISH_RECS_HELP publishes help pages to html

% Copyright (C) 2011-2012 Christophe Gouel
% Licensed under the Expat license, see LICENSE.txt

recsdirectory   = fileparts(which('recsSimul'));
targetdirectory = fullfile(recsdirectory,'html');
PublishOptions = struct('outputDir',targetdirectory);
if exist('html.xsl','file')
  PublishOptions = catstruct(PublishOptions,struct('stylesheet','html.xsl'));
end
PublishOptionsNoExec = catstruct(PublishOptions,struct('evalCode',false));
PublishOptionsNoShow = catstruct(PublishOptions,struct('showCode',false));

delete(fullfile(recsdirectory,'html','*.png'));
delete(fullfile(recsdirectory,'html','*.txt'));
delete(fullfile(recsdirectory,'html','*.yaml'));
delete(fullfile(recsdirectory,'html','*.html'));

%% Documentation
publish('recs_product_page.m',PublishOptions);

% Getting started
publish('getting_started.m',PublishOptions);
publish('installation.m',PublishOptions);
publish('tutorial.m',PublishOptions);
publish('def_sre.m',PublishOptions);
publish('MCP.m',PublishOptions);

% User guide
publish('user_guide.m',PublishOptions);
publish('ug_setting_up.m',PublishOptions);
publish('ug_model_files.m',PublishOptions);
addpath(fullfile(recsdirectory,'demos'))
publish('ug_model_struct.m',PublishOptions);
publish('ug_interpolation.m',PublishOptions);
publish('ss.m',PublishOptions);
publish('first_guess.m',PublishOptions);
publish('solve_REE.m',PublishOptions);
publish('simulate.m',PublishOptionsNoShow);
rmpath(fullfile(recsdirectory,'demos'))
publish('calibration.m',PublishOptions);
publish('accuracy.m',PublishOptions);
publish('finite_horizon.m',PublishOptions);
publish('deterministic.m',PublishOptions);
publish('ug_solvers_eq.m',PublishOptions);
publish('ug_methods.m',PublishOptions);

% Others
publish('recs_functions.m',PublishOptions);
publish('demos.m',PublishOptions);
publish('pathnotinstalled.m',PublishOptions);

%% License
copyfile(fullfile(recsdirectory,'LICENSE.txt'),fullfile(targetdirectory,'LICENSE.txt'));

%% Demonstration
currentfolder = cd(fullfile(recsdirectory,'demos'));
copyfile('cs1.yaml',fullfile(targetdirectory,'cs1.txt'));
copyfile('gro1.yaml',fullfile(targetdirectory,'gro1.txt'));
copyfile('gro2.yaml',fullfile(targetdirectory,'gro2.txt'));
copyfile('sto1.yaml',fullfile(targetdirectory,'sto1.txt'));
copyfile('sto2.yaml',fullfile(targetdirectory,'sto2.txt'));
copyfile('sto4.yaml',fullfile(targetdirectory,'sto4.txt'));
copyfile('sto5.yaml',fullfile(targetdirectory,'sto5.txt'));
publish('clearpublish.m',PublishOptions);
publish('cs1.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('cs2.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('gro1.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('gro2.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('sto1.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('sto2.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('sto3.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('sto4.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('sto5.m',PublishOptions);
publish('clearpublish.m',PublishOptions);
publish('sto6.m',PublishOptions);
publish('cs1model.m',PublishOptionsNoExec);
publish('gro1model.m',PublishOptionsNoExec);
publish('gro2model.m',PublishOptionsNoExec);
publish('sto1model.m',PublishOptionsNoExec);
publish('sto2model.m',PublishOptionsNoExec);
publish('sto4model.m',PublishOptionsNoExec);
publish('sto5model.m',PublishOptionsNoExec);
publish('sto6model.m',PublishOptionsNoExec);
delete(fullfile(recsdirectory,'html','clearpublish.html'));
cd(currentfolder)

builddocsearchdb(fullfile(recsdirectory,'html'));