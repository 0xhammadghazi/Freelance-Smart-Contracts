# A Gas Efficient 2 Wallets Payment Splitter

The contract is well commented; please refer to it as docs, and if there is any question or issues, feel free to open one.  

## Deploy
To deploy the contract simply run the following command:
```bash
npm run deploy
```
You can set the defualt network and `PRIVATE_KEY` in the `.env` file. check [.env.example](.env.example) to see the template.  
For developing purpose, `mainnet` is not in the [hardhat.config.ts](hardhat.config.ts), add it manually if you want to deploy directly to the `mainnet`.

## Event Listener
Set the contract address on .env file and run the following command:
```bash
npm run payment-event-listener
```

## Event Listener in Docker
To start event listener in docker, run the following command:
```bash
docker-compose up -d --build
```
Don't forget to set the environment variables on .env file.  

## Test coverage:  

File                  |  % Stmts | % Branch |  % Funcs |  % Lines |Uncovered Lines |
|:---:|:---:|:---:|:---:|:---:|:---:|
 contracts/           |      100 |       95 |      100 |      100 |                |
  PaymentSplitter.sol |      100 |       95 |      100 |      100 |                |
All files             |      100 |       95 |      100 |      100 |                |
