-include .env

.DEFAULT_GOAL := deploy-anvil

.PHONY: install
install:
	rm -rf lib/forge-std && forge install foundry-rs/forge-std@v1.8.2 --no-commit
	rm -rf lib/openzeppelin-contracts && forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
	rm -rf lib/openzeppelin-contracts-upgradeable && forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.2 --no-commit
	rm -rf lib/openzeppelin-foundry-upgrades && forge install OpenZeppelin/openzeppelin-foundry-upgrades@v0.3.2 --no-commit

.PHONY: clean
clean:
	forge clean

.PHONY: deploy-anvil
deploy-anvil:
	forge script script/DeployGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_LOCAL} --private-key ${PRIVATE_KEY_ANVIL} -vvvv

.PHONY: deploy-holesky
deploy-holesky:
	forge script script/DeployGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_HOLESKY} --private-key ${PRIVATE_KEY_HOLESKY} -vvvv --legacy

.PHONY: validate-deploy-anvil
validate-deploy-anvil: clean
	forge script script/ValidateDeployGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_LOCAL} --private-key ${PRIVATE_KEY_ANVIL} -vvvv

.PHONY: validate-deploy-holesky
validate-deploy-holesky: clean
	forge script script/ValidateDeployGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_HOLESKY} --private-key ${PRIVATE_KEY_HOLESKY} -vvvv --legacy

.PHONY: safe-deploy-sepolia
safe-deploy-sepolia: clean
	forge script script/SafeDeployGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_SEPOLIA} --private-key ${PRIVATE_KEY_ANVIL} --legacy -- --network sepolia -vvvv

.PHONY: validate-upgrade-anvil
validate-upgrade-anvil: clean
	forge script script/ValidateUpgradeGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_LOCAL} --private-key ${PRIVATE_KEY_ANVIL} -vvvv

.PHONY: validate-upgrade-holesky
validate-upgrade-holesky: clean
	forge script script/ValidateUpgradeGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_HOLESKY} --private-key ${PRIVATE_KEY_HOLESKY} -vvvv --legacy

.PHONY: upgrade-anvil
upgrade-anvil:
	forge script script/UpgradeGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_LOCAL} --private-key ${PRIVATE_KEY_ANVIL} -vvvv

.PHONY: upgrade-holesky
upgrade-holesky:
	forge script script/UpgradeGoldsand.s.sol --broadcast --rpc-url ${RPC_NODE_HOLESKY} --private-key ${PRIVATE_KEY_HOLESKY} -vvvv --legacy

.PHONY: fund-anvil
fund-anvil:
	cast send ${CONTRACT_ADDRESS_ANVIL} "fund()" --rpc-url ${RPC_NODE_LOCAL} --from ${FUND_ADDRESS_ANVIL} --private-key ${PRIVATE_KEY_ANVIL} --value 32ether -- -vvvv

.PHONY: fund-sepolia
fund-sepolia:
	cast send ${CONTRACT_ADDRESS_SEPOLIA} "fund()" --rpc-url ${RPC_NODE_SEPOLIA} --from ${FUND_ADDRESS_TESTNET} --private-key ${PRIVATE_KEY_HOLESKY} --value 32ether --legacy -- -vvvv

.PHONY: fund-holesky
fund-holesky:
	cast send ${CONTRACT_ADDRESS_HOLESKY} "fund()" --rpc-url ${RPC_NODE_HOLESKY} --from ${FUND_ADDRESS_TESTNET} --private-key ${PRIVATE_KEY_HOLESKY} --value 32ether --legacy -- -vvvv

.PHONY: read-get-deposit-datas-length-anvil
read-get-deposit-datas-length-anvil:
	cast call ${CONTRACT_ADDRESS_ANVIL} "getDepositDatasLength()" --rpc-url ${RPC_NODE_LOCAL} --private-key ${PRIVATE_KEY_ANVIL} -- -vvvv

.PHONY: read-get-deposit-datas-length-holesky
read-get-deposit-datas-length-holesky:
	cast call ${CONTRACT_ADDRESS_HOLESKY} "getDepositDatasLength()" --rpc-url ${RPC_NODE_HOLESKY} --legacy -- -vvvv

.PHONY: read-deposit-datas-holesky
read-deposit-datas-holesky:
	cast call ${CONTRACT_ADDRESS_HOLESKY} "depositDatas(uint256)" "0" --rpc-url ${RPC_NODE_HOLESKY} --legacy -- -vvvv

.PHONY: clear-deposit-datas-anvil
clear-deposit-datas-anvil:
	cast send ${CONTRACT_ADDRESS_ANVIL} "clearDepositDatas()" --rpc-url ${RPC_NODE_LOCAL} --private-key ${PRIVATE_KEY_ANVIL} -- -vvvv

.PHONY: clear-deposit-datas-holesky
clear-deposit-datas-holesky:
	cast send ${CONTRACT_ADDRESS_HOLESKY} "clearDepositDatas()" --rpc-url ${RPC_NODE_HOLESKY} --from ${FUND_ADDRESS_TESTNET} --private-key ${PRIVATE_KEY_HOLESKY} --legacy  -- -vvvv

.PHONY: verify-holesky
verify-holesky:
	forge verify-contract --chain-id 17000 --num-of-optimizations 200 ${CONTRACT_ADDRESS_HOLESKY} src/Goldsand.sol:Goldsand -e ${ETHERSCAN_API_KEY}
	

.PHONY: setup-contract-roles
setup-contract-roles:
	echo test
