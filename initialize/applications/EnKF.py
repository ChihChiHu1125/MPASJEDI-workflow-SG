#!/usr/bin/env python3

from collections import OrderedDict

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup
from initialize.config.TaskFamily import CylcTaskFamily

from initialize.data.Model import Model
from initialize.data.Observations import benchmarkObservations

from initialize.framework.HPC import HPC
from initialize.framework.Workflow import Workflow

class EnKF(Component):
  defaults = 'scenarios/defaults/enkf.yaml'

  requiredVariables = {
    ## solver [Required Parameter]
    # see classes derived from oops/src/oops/assimilation/LocalEnsembleSolver.h for all options
    'solver': [str,
      ['LETKF', 'GETKF'],
    ],
  }

  variablesWithDefaults = {
    ## Length of Assimilation Time Window
    'timeWindowLength': [6, int],      
          
    ## horizontal observation localization parameters
    'obs localization dimension': ['2D', str, ['2D', '3D']],
    'horizontal localization method': ['Horizontal Gaspari-Cohn', str],
    'horizontal localization lengthscale': [3.0e5, float],
    'horizontal localization lengthscale cloud': [3.0e4, float],
    ## vertical localization (GETKF: model space; LETKF: observation space)
    'vertical localization function': ['Gaspari Cohn', str],
    'vertical localization lengthscale': [6.e3, float],
    'vertical localization lengthscale logp': [1.0, float],
    'vertical localization lengthscale units': ['height', str],
    'fraction of retained variance': [0.95, float],

    # OnlineBC
    'ensembleOnlineBC': [False, bool],
    'EOBC_method': ['prior', str],
    'onlineBC inflation factor': [1.1, float],
    'onlineBC data selection method': ['default', str],
    'onlineBC data selection cloud diff threshold': [5, int],

    # Inflation
    'rtpp value': ['0.4', float],
    'rtps value': ['0.9', float],
    'mult value': ['1.0', float],

    # Control member
    'useControlMember': ['false', str, ['true', 'false']],

    # control member index
    'controlMemberIndex': [0, int],

    # Recenter to Control member
    'recenterToControl': ['true', str, ['true', 'false']],

    # Linear/Nonlinear version
    # Use Linear Operator
    'useLinearOperator': ['true', str, ['true', 'false']],

    # Calculate ensemble OMA
    'diagEnKFOMA': ['True', bool, ['True', 'False']],

    ## observers
    # observation types assimilated in the enkf application
    # Abbreviations:
    #   clr == clear-sky
    #   cld == cloudy-sky
    # OPTIONS besides benchmarkObservations
    ## MW satellite-based
    # amsua-cld_aqua 
    # amsua-cld_metop-a 
    # amsua-cld_metop-b 
    # amsua-cld_n15 
    # amsua-cld_n18 
    # amsua-cld_n19 
    # mhs_n19 
    # mhs_n18 
    # mhs_metop-a 
    # mhs_metop-b 
    ## IR satellite-based
    # abi_g16 
    # ahi_himawari8 
    # abi-clr_g16 
    # ahi-clr_himawari8 
    # iasi_metop-a 
    # iasi_metop-b 
    # iasi_metop-c 
    'observers': [benchmarkObservations, list],

    ## nObsIndent
    # number of spaces to precede members of the 'observers' list in the JEDI YAML
    'nObsIndent': [2, int],

    ## biasCorrection
    # whether to use bias correction coefficients from VarBC
    # OPTIONS: False (not enabled yet)
    'biasCorrection': [False, bool],

    ## directories that stores varBC coefficients that are updated with variational DA
    'staticVarBcDir': ['biasCorrectionCeofficientFilesForUseInEnKF', str],

    ## useBlending
    # whether to apply blending to correct large-scale from global analysis/forecast
    'useBlending': [False, bool],

    ## blendingTarget
    # blending for background or analysis
    'blendingTarget': ['backgroundMean', str, ['background', 'backgroundControlMember', 'backgroundMean', 'analysis', 'analysisControlMember', 'analysisMean']],

    ## blendingGridFile
    # grid list file for blending
    'blendingGridFile': ['/home/project/17001770/weather_department/dae/taosun/MPAS-Files/blending/grid_info.txt', str],

    ## blendinginterval
    # to determine which cycles a blending should be applied (e.g. every 6-h, 12-h, or 24-h)
    'blendingInterval': [24, int, [6, 12, 24]],

    ## blendingVariables
    # list of variables to be blended
    'blendingVariables': [['theta','qv','uReconstructZonal','uReconstructMeridional','rho','surface_pressure'] , list],

    ## blendingLargeScaleFile
    # File template for the large-scale file
    'blendingLargeScaleFile': ['/home/project/17001770/weather_department/cmd/ncar/taosun/regional_mpasjedi/R3km-SG/ICBC-1Hour/{{blendingCycleDate}}/x{{meshRatioOuter}}.{{nCellsOuter}}.init.{{thisMPASFileDate}}.nc', str],

    ## numDigitsOfBlendingFile
    # number of digits of large-scale file for blending
    'numDigitsOfBlendingFile': [3, int],

    ## blendingFileFcstLength
    # forecast range of large-scale blending file
    'blendingFileFcstLength': [0, int],

    ## tropprsMethod
    # method for the tropopause pressure determination used in the
    # cloud detection filter for infrared observations
    # OPTIONS: thompson, wmo (currently the build code only works for thompson)
    'tropprsMethod': ['thompson', str, ['thompson', 'wmo']],

    ## maxIODAPoolSize
    # maximum number of IO pool members in IODA writer class
    # OPTIONS: 1 to NPE, default: 10
    'maxIODAPoolSize': [4, int],

    ## radianceThinningDistance
    # distance (km) used for the Gaussian Thinning filter for all radiance-based observations
    'radianceThinningDistance': [145.0, float],

    ## GNSS RO height top
    # Top of height for GNSS RO assimilation (depend on model top)
    'GNSSROHeightTop': [30000., float],
    'GNSSROHeightBottom': [0., float],

    ## Background check thresholds
    # ABS(Innov.) < ObsError * MaxErrorObs will be assimilated
    'maxErrorObs': [3., float],

    ## For regional domain check lat-lon
    # Observations outside the lat-lon domain check will not go into the memory
    'minLon': [-180., float],
    'maxLon': [ 180., float],
    'minLat': [ -90., float],
    'maxLat': [  90., float],

    ## retainObsFeedback
    # whether to retain the observation feedback files (obs, geovals, ydiag)
    'retainObsFeedback': [True, bool],

    ## post
    # list of tasks for Post
    'post': [['verifyobs'], list],

    ## concatenateObsFeedback
    # whether to concatenate the geovals and ydiag feedback files
    'concatenateObsFeedback': [False, bool],

    ## IR/VIS land surface coefficients classification
    # OPTIONS: USGS, IGBP, NPOESS
    'IRVISlandCoeff': ['IGBP', str],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    meshes:dict,
    model:Model,
    members:Members,
    workflow:Workflow,
    parent:Component,
  ):
    super().__init__(config)

    NN = members.n
    assert NN > 1, ('members.n must be greater than 1')

    self.tf = parent.tf
    self.workDir = parent.workDir

    ###################
    # derived variables
    ###################
    solver = self['solver']
    if solver == 'GETKF':
       assert self['obs localization dimension'] == '2D', ('only 2D obs localization is supported for GETKF')
    self._set('AppName', 'enkf')
    self._set('appyaml', 'enkf.yaml')

    self._set('MeshList', ['EnKF'])
    self._set('nCellsList', [meshes['Outer'].nCells])
    self._set('meshRatioList', [meshes['Outer'].meshRatio])
    self._set('meshModeList', [meshes['Outer'].meshMode])
    self._set('StreamsFileList', [model['outerStreamsFile']])
    self._set('NamelistFileList', [model['outerNamelistFile']])
    self._set('localInvariantFieldsFileList', [model['localInvariantFieldsFileOuter']])

    self._set('TimeStepList', [model['TimeStepOuter'], model['TimeStepInner']])
    self._set('ConfigZdList', [model['ConfigZdOuter'], model['ConfigZdInner']])
    self._set('ApvmUpwindingList', [model['ApvmUpwindingOuter'], model['ApvmUpwindingInner']])
    self._set('DiffusionLengthScaleList', [model['DiffusionLengthScaleOuter'], model['DiffusionLengthScaleInner']])
    self._set('RadiationLWIntervalList', [model['RadiationLWIntervalOuter'], model['RadiationLWIntervalInner']])
    self._set('RadiationSWIntervalList', [model['RadiationSWIntervalOuter'], model['RadiationSWIntervalInner']])
    self._set('PhysicsSuiteList', [model['PhysicsSuiteOuter'], model['PhysicsSuiteInner']])
    self._set('MicrophysicsList', [model['MicrophysicsOuter'], model['MicrophysicsInner']])
    self._set('ConvectionList', [model['ConvectionOuter'], model['ConvectionInner']])
    self._set('PBLList', [model['PBLOuter'], model['PBLInner']])
    self._set('GwdoList', [model['GwdoOuter'], model['GwdoInner']])
    self._set('RadiationCloudList', [model['RadiationCloudOuter'], model['RadiationCloudInner']])
    self._set('RadiationLWList', [model['RadiationLWOuter'], model['RadiationLWInner']])
    self._set('RadiationSWList', [model['RadiationSWOuter'], model['RadiationSWInner']])
    self._set('SfcLayerList', [model['SfcLayerOuter'], model['SfcLayerInner']])
    self._set('LSMList', [model['LSMOuter'], model['LSMInner']])

    # ensemble forecasts
    # EnKF uses online ensemble updating
    self._set('ensPbMemPrefix', workflow.MemPrefix)
    self._set('ensPbMemNDigits', workflow.MemNDigits)
    self._set('ensPbFilePrefix', 'mpasout')
    self._set('ensPbDir0', '{{ExperimentDirectory}}/CyclingFC/{{prevDateTime}}')
    # TODO: replace two lines above with these when forecast includes these attributes
    #self._set('ensPbFilePrefix', forecast.outputFilePrefix)
    #self._set('ensPbDir0', '{{ExperimentDirectory}}/'+forecast.WorkDir+'/{{prevDateTime}}')
    self._set('ensPbDir1', None)
    self._set('ensPbNMembers', NN)

    # TODO: this needs to be non-zero for EnKF workflows that use IAU, get value from forecast
    self._set('ensPbOffsetHR', 0)

    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    # job resource settings

    attr = {
      'retry': {'t': str},
      'baseSeconds': {'t': int},
      'secondsPerMember': {'t': int},
      'nodes': {'t': int},
      'PEPerNode': {'t': int},
      'memory': {'def': '440GB', 't': str},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
      'email': {'def': True, 't': bool},
    }

    # CCH:

    # OnlineBCInflation
    if self['ensembleOnlineBC']:
      r2_onlinebc_inflation = meshes['Outer'].name + '.' + solver + '.onlinebc_inflation'
      onlinebc_inflation_job = Resource(self._conf, attr, ('job', r2_onlinebc_inflation))
      onlinebc_inflation_job._set('seconds', onlinebc_inflation_job['baseSeconds'])
      onlinebc_inflation_task = TaskLookup[hpc.system](onlinebc_inflation_job)

      if self['EOBC_method'] == 'prior':
        r2_onlinebc_prior_update = meshes['Outer'].name + '.' + solver + '.onlinebc_prior_update'
        onlinebc_prior_update_job = Resource(self._conf, attr, ('job', r2_onlinebc_prior_update))
        onlinebc_prior_update_job._set('seconds', onlinebc_prior_update_job['baseSeconds'])
        onlinebc_prior_update_task = TaskLookup[hpc.system](onlinebc_prior_update_job)

        r2_calculate_hbht = meshes['Outer'].name + '.' + solver + '.calculate_hbht'
        calculate_hbht_job = Resource(self._conf, attr, ('job', r2_calculate_hbht))
        calculate_hbht_job._set('seconds', calculate_hbht_job['baseSeconds'])
        calculate_hbht_task = TaskLookup[hpc.system](calculate_hbht_job)        

      elif self['EOBC_method'] == 'posterior':
        r2_onlinebc_posterior_update = meshes['Outer'].name + '.' + solver + '.onlinebc_posterior_update'
        onlinebc_posterior_update_job = Resource(self._conf, attr, ('job', r2_onlinebc_posterior_update))
        onlinebc_posterior_update_job._set('seconds', onlinebc_posterior_update_job['baseSeconds'])
        onlinebc_posterior_update_task = TaskLookup[hpc.system](onlinebc_posterior_update_job)  

    # EnKFObserver
    # r2observer = {{outerMesh}}.observer
    r2observer = meshes['Outer'].name
    r2observer += '.'+solver+'.observer'
    observerjob = Resource(self._conf, attr, ('job', r2observer))
    observerjob._set('seconds', observerjob['baseSeconds'] + observerjob['secondsPerMember'] * NN)
    observertask = TaskLookup[hpc.system](observerjob)

    # EnKFDiagOMA
    if self['diagEnKFOMA'] and self['retainObsFeedback']:
      r2diagoma = meshes['Outer'].name
      r2diagoma += '.'+solver+'.diagoma'
      diagomajob = Resource(self._conf, attr, ('job', r2observer))
      diagomajob._set('seconds', observerjob['baseSeconds'] + observerjob['secondsPerMember'] * NN)
      diagomatask = TaskLookup[hpc.system](diagomajob)

    # EnKF solver
    # r2solver = {{outerMesh}}.{{solver}}
    r2solver = meshes['Outer'].name
    r2solver += '.'+solver+'.solver'

    # add threads attribute
    attr['threads'] = {'def': 1, 't': int}

    solverjob = Resource(self._conf, attr, ('job', r2solver))
    solverjob._set('seconds', solverjob['baseSeconds'] + solverjob['secondsPerMember'] * NN)
    solvertask = TaskLookup[hpc.system](solverjob)

    self._set('solverThreads', solverjob.get('threads'))
    self._cshVars.append('solverThreads')

    args = [
      0,
      self.lower,
      self.workDir+'/{{thisCycleDate}}',
      workflow['CyclingWindowHR'],
      NN,
    ]
    initArgs = ' '.join(['"'+str(a)+'"' for a in args])

    self._tasks += ['''
  ## enkf tasks
  [[InitEnKF]]
    inherit = '''+self.tf.init+''', SingleBatch
    script = $origin/bin/PrepJEDI.csh '''+initArgs+'''
    execution time limit = PT40M
    execution retry delays = '''+solverjob['retry']+'''

  [[EnKFObserver]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/EnKF.csh OMB
'''+observertask.job()+observertask.directives()+'''

  [[EnKFSolver]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/EnKF.csh Solver
'''+solvertask.job()+solvertask.directives()]

    # CCH: if ensemble online bias correction:
    if self['ensembleOnlineBC']: 
      self._tasks += ['''
  [[OnlineBCInflation]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/OnlineBC_Inflation.csh
'''+onlinebc_inflation_task.job()+onlinebc_inflation_task.directives()]
      
      self._dependencies += ['''
        EnKFObserver => OnlineBCInflation  => EnKFSolver''']


      if self['EOBC_method'] == 'prior':
        self._tasks += ['''
  [[OnlineBCPriorUpdate]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/OnlineBC_Prior_Update.csh
'''+onlinebc_prior_update_task.job()+onlinebc_prior_update_task.directives()+'''

  [[CalculateHBHT]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/Calculate_HBHT.csh
'''+calculate_hbht_task.job()+calculate_hbht_task.directives()]  

        self._dependencies += ['''
        OnlineBCInflation => CalculateHBHT => OnlineBCPriorUpdate''']

      elif self['EOBC_method'] == 'posterior':   
        self._tasks += ['''
  [[OnlineBCPosteriorUpdate]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/OnlineBC_Posterior_Update.csh
'''+onlinebc_posterior_update_task.job()+onlinebc_posterior_update_task.directives()]

        self._dependencies += ['''
        EnKFDiagOMA => OnlineBCPosteriorUpdate''']

    else:
      self._dependencies += ['''
        EnKFObserver => EnKFSolver''']



    if self['diagEnKFOMA'] and self['retainObsFeedback']:
      self._tasks += ['''
  [[EnKFDiagOMA]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/EnKF.csh OMA
'''+diagomatask.job()+diagomatask.directives()]
    if self['ensembleOnlineBC'] and self['EOBC_method'] == 'prior':
      self._dependencies += ['''
        EnKFSolver & OnlineBCPriorUpdate => EnKFDiagOMA => '''+self.tf.post]
    else:
      self._dependencies += ['''
        EnKFSolver => EnKFDiagOMA => '''+self.tf.post]

    if self['concatenateObsFeedback']:
      concatattr = {
        'seconds': {'def': 300},
        'nodes': {'def': 1},
        'PEPerNode': {'def': 128},
        'memory': {'def': '440GB', 'typ': str},
        'queue': {'def': hpc['CriticalQueue']},
        'account': {'def': hpc['CriticalAccount']},
      }
      concatjob = Resource(self._conf, concatattr, ('concat.job'))
      concattask = TaskLookup[hpc.system](concatjob)
      args = [
      self.lower,
      self.workDir+'/{{thisCycleDate}}',
      "",
      ]
      concatArgs = ' '.join(['"'+str(a)+'"' for a in args])
      self._tasks += ['''
  [[ConcatEnKF]]
    inherit = BATCH
    script = $origin/bin/ConcatenateObsFeedback.csh '''+concatArgs+'''
'''+concattask.job()+concattask.directives()]
      self._dependencies += ['''
        EnKFSolver => ConcatEnKF'''+self.tf.post]

    ##### In the following, we implement blending for the EnKF-based approach.
    if self['useBlending']:
      
      blendingattr = {
        'seconds': {'def': 300},
        'nodes': {'def': 4},
        'PEPerNode': {'def': 128},
        'memory': {'def': '440GB', 'typ': str},
        'queue': {'def': hpc['CriticalQueue']},
        'account': {'def': hpc['CriticalAccount']},
      }
      r2blending = meshes['Outer'].name
      r2blending += '.'+solver+'.blending'
      blendingjob = Resource(self._conf, blendingattr, ('job', r2blending))
      blendingtask = TaskLookup[hpc.system](blendingjob)

      # ============================================================
      # 1. Member-wise blending (background / analysis)
      # ============================================================
      if self['blendingTarget'] in ['background', 'analysis']:
        
        for mm in range(NN):
          args = [
            'enkf',
            mm+1,
          ]
          blendingArgs = ' '.join(['"' + str(a) + '"' for a in args])
          
          self._tasks += [ '''
  [[EnKFBlending_''' + str(mm+1) + ''']]  
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/Blending.csh ''' + blendingArgs + '''
''' + blendingtask.job() + blendingtask.directives() ]

          if self['blendingTarget'] == "background":
            self._dependencies += ['''
        EnKFBlending_''' + str(mm+1) + ''' => EnKFObserver''']
          else:
            self._dependencies += ['''
        EnKFDiagOMA => EnKFBlending_''' + str(mm+1) + ''' => ''' + self.tf.post]

      # ============================================================
      # 2. Background control member / Mean
      #    - If Background Mean, need to calculate EnsMean first
      # ============================================================
      elif self['blendingTarget'] in ['backgroundControlMember', 'backgroundMean']:

        args = [
          'enkf',
          0,
        ]
        blendingArgs = ' '.join(['"'+str(a)+'"' for a in args])
        
        self._tasks += [ '''
  [[EnKFBlending]]  
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/Blending.csh ''' + blendingArgs + '''
''' + blendingtask.job() + blendingtask.directives() ]

        if self['blendingTarget'] == 'backgroundMean':
          self._dependencies += ['''
        MeanBackground => EnKFBlending => EnKFObserver''']
        else:
          self._dependencies += ['''
        EnKFBlending => EnKFObserver''']

      # ============================================================
      # 3. Analysis control member / Mean
      #    - Do blending first, then recenter)
      # ============================================================
      elif self['blendingTarget'] in ['analysisControlMember', 'analysisMean']:
        
        # Step 1: blending
        args = [
          'enkf',
          0,
        ]
        blendingArgs = ' '.join(['"'+str(a)+'"' for a in args])
        
        self._tasks += [ '''
  [[EnKFBlending]]  
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/Blending.csh ''' + blendingArgs + '''
''' + blendingtask.job() + blendingtask.directives() ]

        # Step 2: recenetring
        self._tasks += [ '''
  [[EnKFRecenter]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/RecenterEnsemble.csh analysis
''' + blendingtask.job() + blendingtask.directives() ]

        self._dependencies += ['''
        EnKFDiagOMA => EnKFBlending => EnKFRecenter => ''' + self.tf.post]
