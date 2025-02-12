import {ApiError, ApiResponse, ApiResults} from "common";

const apiPrefix = '/api/v1'

const headers = {
    'Content-Type': 'application/json'
}

const handleError = (err: any): ApiError => {
    if (err.error?.statusCode && err.error?.name)
        return err
    return {
        status: 'error',
        error: {
            name: 'ServerError',
            statusCode: 500,
            message: `Unexpected error from backend ${err}`,
            data: err
        }
    }
}

type LightdashApiProps = {
    method: 'GET' | 'POST'
    url: string,
    body: BodyInit | null | undefined,
}
export const lightdashApi = async <T extends ApiResults>({ method, url, body }: LightdashApiProps): Promise<T> => {
    return fetch(`${apiPrefix}${url}`, {method, headers, body})
        .then(r => {
            if (!r.ok)
                return r.json().then(d => { throw d })
            return r
        })
        .then(r => r.json())
        .then((d: ApiResponse) => {
            switch (d.status) {
                case "ok": return d.results as T
                case "error": throw d
                default: throw d
            }
        })
        .catch(err => {throw(handleError(err))})
}