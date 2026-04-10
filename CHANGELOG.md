# Changelog

---
## [1.1.0]

### Bug Fixes

- **(batch)** fix flushBatch re-entrancy and add buffer shrink - ([e0527db](https://github.com/arxdeus/pureflow/commit/e0527db163f410a5dd4d36dc46510fde25c001b7))
- **(benchmark)** equals benchmarks - ([dbcb047](https://github.com/arxdeus/pureflow/commit/dbcb0470e4b2f691f77fa0a7229d08f9ad87bfd3))
- **(dependency_node)** remove stale methods - ([42ff561](https://github.com/arxdeus/pureflow/commit/42ff56141933482190bd9cc6dfaecf4f2eb80c44))
- **(observer)** fix export order and doc imports in observer - ([5e43d7f](https://github.com/arxdeus/pureflow/commit/5e43d7f0d3d0f5eac4e4d85512a985aef16cfe5f))
- styling fixes - ([b24b9b5](https://github.com/arxdeus/pureflow/commit/b24b9b5c4dd70c4e01a356d43ff42d35bfc49566))
- readability - ([9b319c3](https://github.com/arxdeus/pureflow/commit/9b319c3a0259cc7918059427aa0b0657ebcba4ac))

### Features

- **(computed)** add debugLabel and observer hooks to Computed - ([6f8623a](https://github.com/arxdeus/pureflow/commit/6f8623ae79c822cf1fca88f4e7b5d1597f3f95de))
- **(observer)** add FlowObserver class and Pureflow accessor - ([8e606ad](https://github.com/arxdeus/pureflow/commit/8e606ad658d3e196517919436dba559da8eb8276))
- **(pipeline)** add debugLabel and observer hooks to Pipeline - ([37259d4](https://github.com/arxdeus/pureflow/commit/37259d411adcfea56628b13e48d6feefa96e270f))
- **(store)** add debugLabel to Store with observer hooks - ([ec49b05](https://github.com/arxdeus/pureflow/commit/ec49b058e0be5826353b1456a21d328803c3e2e6))

### Miscellaneous Chores

- **(interfaces)** `ReactiveValueObservable` styling - ([7541b46](https://github.com/arxdeus/pureflow/commit/7541b4626cfdcff9da6e1a59031bfef580bcf4f0))
- styling - ([436dce0](https://github.com/arxdeus/pureflow/commit/436dce06eebeb30253377be309efa2f887168baf))

### Performance

- **(dependency_node)** remove DependencyNode object pool - ([1ab7257](https://github.com/arxdeus/pureflow/commit/1ab725733c092c31ccd3ddc06a4a640aa3a46034))
- **(pipeline)** use ListQueue and cache tear-offs in pipeline - ([cf04ae9](https://github.com/arxdeus/pureflow/commit/cf04ae9398ccda3ee49efca03f37e33a6535450c))
- **(pureflow)** remove prefer-inline from methods with loops - ([04f8ca5](https://github.com/arxdeus/pureflow/commit/04f8ca56ddd0431388d6b53b2c8b5b1ef9957499))
- **(reactive)** use O(1) listenernode removal in cancel() - ([ea9d831](https://github.com/arxdeus/pureflow/commit/ea9d8316e2767b146b544a57497ba8f295160639))
- **(state)** replace nullable _equality with non-nullable _equals - ([c63c5a2](https://github.com/arxdeus/pureflow/commit/c63c5a25e22295793e3846be90c192c34d8fea61))

### Refactoring

- **(state)** fold inBatch and _hasValue into bit flags - ([8775fb2](https://github.com/arxdeus/pureflow/commit/8775fb2538fad2582b67ac1e78aadd05dbf54c23))

---
## [1.0.2]

### Bug Fixes

- `ReactiveValueObservable` to exports - ([53a3c61](https://github.com/arxdeus/pureflow/commit/53a3c61064f7d8ce3ca7fe0512db2de667303294))

### Performance

- **(store_impl)** optimize notification logic to skip unnecessary notifications when there are no listeners - ([ee2ee43](https://github.com/arxdeus/pureflow/commit/ee2ee4365d4a78832e6cbd93bd429e047f457fe5))

---
## [1.0.1]

### Bug Fixes

- imports - ([5b2f1d1](https://github.com/arxdeus/pureflow/commit/5b2f1d1cd81b378ce36142fcfac8caf56ff94601))
- hide internal fields - ([aecfc99](https://github.com/arxdeus/pureflow/commit/aecfc9924c39c8a02bf6e0afae080d5c556aba60))
- symlinks - ([02c8ab5](https://github.com/arxdeus/pureflow/commit/02c8ab5eedfc00d05179a47984c7a14b27b9eb5a))
- meta any version - ([514e23d](https://github.com/arxdeus/pureflow/commit/514e23de1f1671f24cf200bdecac2c25e59328a9))
- naming issues - ([1968715](https://github.com/arxdeus/pureflow/commit/19687153d32a707b8eafae81d1a35a62945f40a0))
- meta version - ([e4689de](https://github.com/arxdeus/pureflow/commit/e4689de26e66323312743749afba448eec2fa299))

### Features

- custom equality - ([c9e3837](https://github.com/arxdeus/pureflow/commit/c9e38374f8b05f1711741dfb77ef63a7de1efdd0))
- prepare to initial release - ([99914a2](https://github.com/arxdeus/pureflow/commit/99914a2c0557f74fa0c5e83c950bba029f09ef6c))

### Miscellaneous Chores

- update .pubignore files for pureflow and pureflow_flutter packages - ([106baf7](https://github.com/arxdeus/pureflow/commit/106baf7afb2912bd6d51fc07ac2cd38c139b1a7f))
- symlinks - ([9e2bbb3](https://github.com/arxdeus/pureflow/commit/9e2bbb3a9a752b98ce95840478636f09108bbf49))

### Refactoring

- move `pureflow` to packages - ([a2c9d40](https://github.com/arxdeus/pureflow/commit/a2c9d4002cb5a5394899464c3b036e8546e36f56))
- replace `Store.batch` with `batch` for improved API consistency - ([787b6fc](https://github.com/arxdeus/pureflow/commit/787b6fc98a7b55a042beabd25f7b59a4a1980c88))

## 1.0.0

- Initial release
