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

const args = process.argv.slice(2);

if (args.length === 0) {
   exit(1, "You have to provide at least on dataFeed");
}

const dataFeed = args[0];
const historicalTimestamp = args[1];

(async function (dataFeed, historicalTimestamp) {
   let redstonePayload;
   if (historicalTimestamp) {
      redstonePayload = await (new DataServiceWrapper({
         dataServiceId: "redstone-primary-prod",
         dataPackagesIds: [dataFeed],
         uniqueSignersCount: 3,
         historicalTimestamp: Number(historicalTimestamp) * 1000
      }).getRedstonePayloadForManualUsage());
   } else {
      redstonePayload = await (new DataServiceWrapper({
         dataServiceId: "redstone-primary-prod",
         dataPackagesIds: [dataFeed],
         uniqueSignersCount: 3,
      }).getRedstonePayloadForManualUsage());
   }

   process.stdout.write(redstonePayload);
   process.exit(0);
})(dataFeed, historicalTimestamp);