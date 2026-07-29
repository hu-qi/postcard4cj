# LLT 覆盖率报告

本目录保存 2026-07-29 使用 Cangjie LTS 1.0.5 在 `main` 分支生成的可审阅覆盖率制品。

## 覆盖率结果

| 统计口径 | 命中行 / 总行数 | 覆盖率 |
|---|---:|---:|
| `src` 下全部 instrumented 文件 | 3853 / 5813 | 66.28% |
| 排除测试、benchmark 和编译期宏包的运行时代码 | 2106 / 2935 | 71.75% |

编译期宏包包含在全部源码的分母中，但宏展开不属于运行时执行，因此其命中率不能代表宏功能是否经过测试。宏功能由 `postcard_macro_test` 和 `derive_ng_test` 的 40 项行为测试验证。

## 报告文件

- [HTML 总览](index.html)
- [JSON 原始数据](coverage.json)
- [Cobertura XML 数据](coverage.xml)
- [完整 LLT 测试报告](../LLT.md)

各个 `*.cj.html` 文件是对应源码的逐行命中详情。原始 `.gcno`、`.gcda` 位于本地 `cov_output`，属于构建中间产物，不提交到仓库。

## 复现

```bash
cjpm test --coverage -V
cjcov \
  --root="$(pwd)/cov_output" \
  --source="$(pwd)/src" \
  --html-details \
  --xml \
  --json \
  --output="$(pwd)/doc/cjcov"
```

项目采用 `-O2`；覆盖率命令会给出“应在无优化模式下使用”的提示。本报告为保持发布配置一致而保留 `-O2`，覆盖率趋势比较时必须保持相同配置。
