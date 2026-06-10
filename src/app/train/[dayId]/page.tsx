import { TrainingSession } from './client';

export function generateStaticParams() {
  const params: { dayId: string }[] = [];
  for (let week = 1; week <= 4; week++) {
    for (let day = 1; day <= 7; day++) {
      params.push({ dayId: `${week}-${day}` });
    }
  }
  return params;
}

export default function Page() {
  return <TrainingSession />;
}
