SELECT referral_date, mediator_appointment_date, mediator_name, *
FROM vw_all_case vac 
WHERE 
mediator_appointment_date BETWEEN '2021-05-21' AND '2021-07-26' AND referral_date <= '2021-07-26'

OR (mediator_name IS NOT NULL AND referral_date >= '2021-05-21' AND referral_date <= '2021-07-26' AND mediator_appointment_date IS NULL)

ORDER BY referral_date

SELECT referral_date, mediator_appointment_date, mediator_name, *
FROM vw_all_case
WHERE referral_date >= '2021-07-26'
	OR mediator_appointment_date >= '2021-07-26'
ORDER BY referral_date 

SELECT *
FROM vw_all_case
WHERE