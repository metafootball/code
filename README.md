# 说明
### 1 脚本中的地址为测试地址，金额也是测试随意使用，请替换
### 2 脚本中的底池地址和金额为测试数据，请替换
### 3 periphery中的RateLSwapRouter为专门为该项目写的router，添加了白名单功能
- 先发布该ROUTER，FUGOUYUN页面和合约是用该ROUTER用来添加白名单，需要添加下面两个合约地址
- 测试网WMEER=0x4E0008923DB5777Df6EFD8594710fdB67eb0DB69
- 测试网FACTORY=0x49eEc459e7470CaE00a13Ec4678B9ef49B672086
- 测试场initCoder=0x2da8ec683ddaab98e07d37cebf3c18ade22888b712f6825b2fb614eae072ed20
### 4 如使用现有脚本，则执行顺序为
- 手动：发布router合约
- 脚本：修改参数，执行publish.js 发布FY，HFY，fugouyun质押合约，smartAMM合约
- 手动：router 添加fugouyun，smartAMM 地址为白名单
- 脚本：修改参数，执行initpool.js
### 5 如需要在添加底池前，底池用户绑定关系，则需先发布fy，互用绑定完关系后再执行初始化地址脚本
### 6 合约未审计