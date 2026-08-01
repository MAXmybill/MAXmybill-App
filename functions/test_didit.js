const axios = require('axios');

async function testDidit() {
    try {
        const response = await axios.post('https://verification.didit.me/v3/phone/send/', {
            phone: '+917010783677'
        }, {
            headers: {
                'x-api-key': 'v3kqn4hAr23aNorrVOc5m9aBEIOrsOB6lJaNqI3F-xA',
                'Content-Type': 'application/json'
            }
        });
        console.log("Success:", response.data);
    } catch (error) {
        console.error("Error:", error.response?.data || error.message);
    }
}
testDidit();
