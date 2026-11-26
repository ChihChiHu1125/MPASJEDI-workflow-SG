#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

import re

from initialize.applications.HofX import HofX as HofXApp
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.Model import Model
from initialize.data.Observations import Observations
from initialize.data.InvariantStream import InvariantStream
from initialize.data.StateEnsemble import StateEnsemble

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.Naming import Naming

from initialize.suites.SuiteBase import SuiteBase

class HofX(SuiteBase):
  '''
  H(x) of existing MPAS states only; no DA, forecast, or external analyses.
  Each cycle point is the valid time of the states.  For every entry under hofx.states,
  e.g.,

    hofx:
      states:
        bg:
          directory: /path/to/CyclingDA/{{thisCycleDate}}/bg
          prefix: bg
        an:
          directory: /path/to/CyclingDA/{{thisCycleDate}}/an
          prefix: an

  the suite runs InitHofX<NAME> => HofX<NAME> on <directory>/<prefix>.YYYY-MM-DD_HH.00.00.nc
  at every cycle point, writing to Verification/<name>/.  directory may contain
  {{thisCycleDate}} (valid time) and {{prevCycleDate}} (valid time - CyclingWindowHR).
  '''
  def __init__(self, conf:Config):
    super().__init__(conf)

    self.c['model'] = Model(conf)
    meshes = self.c['model'].getMeshes()

    self.c['build'] = Build(conf, self.c['model'])
    self.c['observations'] = Observations(conf, self.c['hpc'])
    self.c['members'] = Members(conf)
    assert self.c['members'].n == 1, 'HofX suite: only single-member states are supported'

    self.c['experiment'] = Experiment(conf, self.c['hpc'])
    self.c['ss'] = InvariantStream(conf, meshes, self.c['workflow']['FirstCycleDate'], None, self.c['experiment'])
    self.c['naming'] = Naming(conf, self.c['experiment'])

    states = conf.get('hofx.states')
    assert isinstance(states, dict) and len(states) > 0, (
      'HofX suite: hofx.states must map names to {directory, prefix}')

    hofxNames = []
    for name, s in states.items():
      assert re.fullmatch('[A-Za-z0-9]+', name), (
        'HofX suite: hofx.states names must be alphanumeric, not '+name)
      assert isinstance(s, dict) and 'directory' in s and 'prefix' in s, (
        'HofX suite: hofx.states.'+name+' requires directory and prefix')

      state = StateEnsemble(meshes['Outer'])
      state.append({
        'directory': str(s['directory']),
        'prefix': str(s['prefix']),
      })

      key = 'hofx_'+name
      self.c[key] = HofXApp(conf, {
        'hpc': self.c['hpc'],
        'model': self.c['model'],
        'mesh': meshes['Outer'],
        'states': state,
        'sub directory': name,
        'dependencies': [self.c['observations']['PrepareObservations']],
        'window': self.c['workflow']['CyclingWindowHR'],
      })
      hofxNames.append(key)

    for k, c_ in self.c.items():
      c_.export()

    # H(x) at every cycle point, starting at the first one
    self._dependencies += ['''
    PT'''+str(self.c['workflow']['CyclingWindowHR'])+'''H = """''']
    for k in hofxNames:
      self._dependencies += self.c[k]._dependencies
    self._dependencies += ['''
      """''']

    self.queueComponents += ['observations']

    self.taskComponents += ['observations'] + hofxNames
