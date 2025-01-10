const {
   WrapperBuilder,
   DataServiceWrapper
} = require("@redstone-finance/evm-connector");
const {
   appendFileSync
} = require('fs');
const {
   stdout
} = require("process");
const {
   ethers
} = require("ethers");

const args = process.argv.slice(2);

if (args.length === 0) {
   process.exit(1, "You have to provide at least on dataFeed");
}

const dataFeed = args[0];
const timestamp = args[1];

(async function (dataFeed, timestamp) {

   if (timestamp) {
      let data = await (new DataServiceWrapper({
         dataServiceId: "redstone-primary-prod",
         dataPackagesIds: [dataFeed],
         uniqueSignersCount: 1,
         historicalTimestamp: Number(timestamp) * 1000

      }).getDataPackagesForPayload());

      let priceValue = Math.ceil(Number(data[0].dataPackage.dataPoints[0].metadata.value) * 10 ** 8);
      const encodedData = ethers.utils.defaultAbiCoder.encode(["uint256"], [priceValue]);

      process.stdout.write(encodedData);
      process.exit(0);
   } else {
      let data = await (new DataServiceWrapper({
         dataServiceId: "redstone-primary-prod",
         dataPackagesIds: [dataFeed],
         uniqueSignersCount: 1,
      }).getDataPackagesForPayload());

      let priceValue = Math.floor(Number(data[0].dataPackage.dataPoints[0].metadata.value) * 10 ** 8);
      const encodedData = ethers.utils.defaultAbiCoder.encode(["uint256"], [priceValue]);

      process.stdout.write(encodedData);
      process.exit(0);
   }
})(dataFeed, timestamp);