#!/bin/csh -f

####################################
## workflow-relevant state variables
####################################
set MPASHydroIncrementVariables = (qc qi qg qr qs)
set MPASHydroStateVariables = (${MPASHydroIncrementVariables} cldfrac)

set StandardAnalysisVariables = ( \
  spechum \
  surface_pressure \
  temperature \
  uReconstructMeridional \
  uReconstructZonal \
)
set StandardStateVariables = ( \
  $StandardAnalysisVariables \
  theta \
  rho \
  u \
  w \
  qv \
  pressure \
  landmask \
  observable_domain_mask \
  xice \
  snowc \
  skintemp \
  ivgtyp \
  isltyp \
  snowh \
  vegfra \
  u10 \
  v10 \
  t2m \
  q2 \
  lai \
  smois \
  tslb \
  pressure_p \
  #refl10cm \
)

set MPASJEDIVariablesFiles = (\
  geovars.yaml \
  obsop_name_map.yaml \
  keptvars.yaml \
)

set SACAStateVariables = ( \
  temperature \
  spechum \
  theta \
  u \
  rho \
  qv \
  qc \
  qi \
  qs \
  ni \
  cldfrac \
  xland \
  pressure \
  pressure_p \
  surface_pressure \
)
